// dz_osc_ch.v - one channel of the DDS pattern engine (2026-10-29; ROADMAP.md
// section 14): phase generator, segment sequencer, raster sync, shapes with
// its own sine table, AWG. Used twice by dz_osc2.v (the AXI top), which
// synchronizes the raster events and decodes the registers. Clock: FCLK0.
//
// Registers (byte offset inside the channel's 16 KB):
//   0x00 PINC      [31] valid, [30:0] base phase increment (f = PINC * 100 MHz
//                  / 2^32). As in the old dds_axi_interface: a write without
//                  bit 31 is IGNORED. Reset 0x8000_0001 (the old default).
//   0x04 STATUS    RO [0] PINC valid (old "TVALID"), [11:8] step, [16] running
//   0x08 CTRL      [0] sequencer on
//                  [3:1] tick: 0 prescaler, 1 hsync, 2 vsync, 3 line start
//                        (DE rise), 4 other channel step, 5 other channel
//                        wrap, 6 external trigger, 7 none
//                  [5:4] phase reset: 0 none, 1 hsync, 2 vsync, 3 line start
//                  [11:8] last step (the table loops 0..last)
//                  [12] one shot (stop after the last step, keep its values)
//                  [13] restart the table at each vsync
//                  [14] commit at vsync: PINC, POFF and CTRL take effect at
//                       the next vsync (tear-free); 0 = at once. PRESCALE,
//                       LINESTEP, FRAMESTEP, PWIDTH act at once
//                  [18:16] shape: 0 sine, 1 saw up, 2 saw down, 3 triangle,
//                       4 square, 5 pulse (phase < PWIDTH), 6 AWG
//                  [19] invert the output MSB (two's complement <-> offset
//                       binary; the sine is two's complement, as the old
//                       DDS compiler's)
//   0x0C PRESCALE  [23:0] FCLK0 clocks per prescaler tick - 1
//   0x10 POFF      phase offset
//   0x14 LINESTEP  added to the phase at each hsync, cleared at vsync
//   0x18 FRAMESTEP added to the phase at each vsync
//   0x1C PWIDTH    pulse width: shape 5 is high while phase < PWIDTH
//   0x20 INC       RO phase increment now
//   0x24 PHASE     RO phase now
//   0x28 ID        RO "DOSC" (0x444F5343)
//   0x100 + 16*i   step i (0..15), WRITE-ONLY (the software keeps a copy):
//                  +0 START (increment at the start of the step), +4 DELTA
//                  (signed, added at each tick), +8 [23:0] LEN (ticks; 0 = 1),
//                  [24] KEEP (do not load START: continue from the current
//                  increment), [25] RST (restart the phase accumulator when
//                  the step starts), +C PHASE (offset while the step runs)
//   0x2000-0x3FFC  AWG table, WRITE-ONLY: 2048 x 16 bit (bits [15:0] of each
//                  word), indexed by phase[31:21]; one BRAM tile
//
// Outputs, 3 clocks after the phase: wave_out (the selected shape: the old
// sine leg) and phase_out = phase[31:16] (the old phase leg). phase = the
// full phase without delay (for the event block).
//
// Shapes:  square A/B = {A,0,N} {B,0,N};  pulse = {A,0,N1} {B,0,N2};
//          ramp = {A,+d,N} (loop);  triangle = {A,+d,N} {KEEP,-d,N};
//          8x8 checkerboard: PINC = 8 cycles per line, phase reset at
//          hsync, tick hsync, {P,0,rows} {P,0,rows | PHASE 0x8000_0000}.
`timescale 1ns / 1ps
module dz_osc_ch (
    input  wire        clk,
    input  wire        rst,        // registers to their reset values
    // register bus from dz_osc2 (channel-local byte address)
    input  wire        we,
    input  wire [13:0] waddr,
    input  wire [31:0] wdata,
    input  wire [3:0]  wstrb,
    input  wire [13:0] raddr,
    output reg  [31:0] rdata,      // combinational from raddr
    // raster events, already synchronized into clk (one-clock pulses)
    input  wire        vs_e,
    input  wire        hs_e,
    input  wire        de_e,
    input  wire        ex_e,
    // chaining with the other channel
    input  wire        chain_step_in,
    input  wire        chain_wrap_in,
    output reg         step_pulse = 0,
    output reg         wrap_pulse = 0,
    // outputs
    output wire [31:0] phase,
    output reg  [15:0] wave_out = 0,
    output reg  [15:0] phase_out = 0
);
    // ---- registers (s_ = as written; a_ = in effect) ------------------------------
    reg [31:0] s_pinc = 32'h8000_0001, s_ctrl = 0, s_poff = 0;
    reg [31:0] a_pinc = 32'h8000_0001, a_ctrl = 0, a_poff = 0;
    reg [23:0] presc = 0;
    reg [31:0] lstep = 0, fstep = 0, pw = 32'h8000_0000;
    // step table (LUTRAM, one read address), AWG table (BRAM)
    reg [31:0] st_start [0:15];
    reg [31:0] st_delta [0:15];
    reg [31:0] st_ctl   [0:15];
    reg [31:0] st_phase [0:15];
    reg [15:0] awg      [0:2047];
    integer k;
    initial begin
        for (k = 0; k < 16; k = k + 1) begin
            st_start[k] = 0; st_delta[k] = 0; st_ctl[k] = 0; st_phase[k] = 0;
        end
    end

    // ---- register writes ---------------------------------------------------------------
    integer b;
    always @(posedge clk) begin
        if (rst) begin
            s_pinc <= 32'h8000_0001; s_ctrl <= 0; s_poff <= 0;
            presc <= 0; lstep <= 0; fstep <= 0; pw <= 32'h8000_0000;
        end else if (we) begin
            if (waddr[13]) begin
                if (wstrb[0]) awg[waddr[12:2]][7:0] <= wdata[7:0];
                if (wstrb[1]) awg[waddr[12:2]][15:8] <= wdata[15:8];
            end else if (waddr[13:8] == 6'h01) begin
                case (waddr[3:2])
                    2'd0: st_start[waddr[7:4]] <= wdata;
                    2'd1: st_delta[waddr[7:4]] <= wdata;
                    2'd2: st_ctl[waddr[7:4]]   <= wdata;
                    2'd3: st_phase[waddr[7:4]] <= wdata;
                endcase
            end else if (waddr[13:8] == 6'h00) begin
                // PINC: a write without the valid bit is ignored (old block)
                if (waddr[7:2] == 6'h00 && wstrb[3] && wdata[31])
                    s_pinc <= wdata;
                for (b = 0; b < 4; b = b + 1)
                    if (wstrb[b])
                        case (waddr[7:2])
                            6'h02: s_ctrl[8*b +: 8] <= wdata[8*b +: 8];
                            6'h03: if (b < 3) presc[8*b +: 8] <= wdata[8*b +: 8];
                            6'h04: s_poff[8*b +: 8] <= wdata[8*b +: 8];
                            6'h05: lstep[8*b +: 8]  <= wdata[8*b +: 8];
                            6'h06: fstep[8*b +: 8]  <= wdata[8*b +: 8];
                            6'h07: pw[8*b +: 8]     <= wdata[8*b +: 8];
                            default: ;
                        endcase
            end
        end
    end
    // commit: the a_ copies follow at once, or at vsync
    always @(posedge clk)
        if (!s_ctrl[14] || vs_e) begin
            a_pinc <= s_pinc; a_ctrl <= s_ctrl; a_poff <= s_poff;
        end

    // ---- tick ------------------------------------------------------------------------
    reg [23:0] presc_cnt = 0;
    reg        presc_tick = 0;
    always @(posedge clk) begin
        presc_tick <= presc_cnt == 0;
        presc_cnt <= (presc_cnt == 0) ? presc : presc_cnt - 24'd1;
    end
    reg tick;
    always @* begin
        case (a_ctrl[3:1])
            3'd0: tick = presc_tick;
            3'd1: tick = hs_e;
            3'd2: tick = vs_e;
            3'd3: tick = de_e;
            3'd4: tick = chain_step_in;
            3'd5: tick = chain_wrap_in;
            3'd6: tick = ex_e;
            default: tick = 1'b0;
        endcase
    end
    reg ph_rst;
    always @* begin
        case (a_ctrl[5:4])
            2'd1: ph_rst = hs_e;
            2'd2: ph_rst = vs_e;
            2'd3: ph_rst = de_e;
            default: ph_rst = 1'b0;
        endcase
    end

    // ---- sequencer ---------------------------------------------------------------------
    // start: sequencer switched on; restart: CTRL[13] at vsync (also after a
    // one shot ended); advance: the step's last tick; finish: a one shot's
    // last step ended (its increment and phase stay)
    reg [3:0]  step = 0;
    reg [23:0] cnt = 0;
    reg [31:0] seq_inc = 0, seq_phase = 0, seq_delta = 0;
    reg        running = 0, done = 0, step_rst = 0;
    wire       seq_on = a_ctrl[0];
    wire [3:0] last = a_ctrl[11:8];
    wire       at_last = step == last;
    wire       start = seq_on && !running && !done;
    wire       restart = seq_on && a_ctrl[13] && vs_e;
    wire       advance = running && tick && cnt == 0;
    wire       finish = advance && at_last && a_ctrl[12];
    wire       enter = start || restart || (advance && !finish);
    wire [3:0] ent = (start || restart || at_last) ? 4'd0 : step + 4'd1;
    wire [31:0] ent_ctl = st_ctl[ent];
    always @(posedge clk) begin
        step_pulse <= 1'b0;
        wrap_pulse <= 1'b0;
        step_rst <= 1'b0;
        if (!seq_on) begin
            running <= 1'b0;
            done <= 1'b0;
            step <= 0;
        end else if (enter) begin
            running <= 1'b1;
            done <= 1'b0;
            step <= ent;
            cnt <= (ent_ctl[23:0] == 0) ? 24'd0 : ent_ctl[23:0] - 24'd1;
            if (!ent_ctl[24]) seq_inc <= st_start[ent];
            seq_phase <= st_phase[ent];
            seq_delta <= st_delta[ent];
            step_rst <= ent_ctl[25];
            step_pulse <= 1'b1;
            wrap_pulse <= advance && at_last;          // the table looped
        end else if (finish) begin
            running <= 1'b0;
            done <= 1'b1;
        end else if (running && tick) begin
            cnt <= cnt - 24'd1;
            seq_inc <= seq_inc + seq_delta;
        end
    end

    // ---- phase -------------------------------------------------------------------------
    // base increment: as before, only a PINC write with bit 31 changes it
    wire [31:0] inc = (seq_on && (running || done)) ? seq_inc : {1'b0, a_pinc[30:0]};
    reg [31:0] acc = 0, line_off = 0, frame_off = 0;
    reg [31:0] t1 = 0, t2 = 0, ph = 0;
    always @(posedge clk) begin
        acc <= (ph_rst || step_rst) ? 32'd0 : acc + inc;
        if (vs_e) begin
            line_off <= 0;
            frame_off <= frame_off + fstep;
        end else if (hs_e)
            line_off <= line_off + lstep;
        t1 <= acc + a_poff;
        t2 <= line_off + frame_off + seq_phase;
        ph <= t1 + t2;
    end
    assign phase = ph;

    // ---- shapes: 3 clocks from ph to wave_out --------------------------------------------
    // stage 1: sine ROM (quarter wave: mirror in quadrants 1, 3), AWG read, others
    wire [9:0]  sidx = ph[30] ? ~ph[29:20] : ph[29:20];
    wire [15:0] srom;
    dz_sine_rom sine_rom (.clk(clk), .addr(sidx), .data(srom));
    reg [15:0] shp = 0, awg_q = 0, ph1 = 0;
    reg [2:0]  shape1 = 0;
    reg        neg1 = 0;
    always @(posedge clk) begin
        awg_q <= awg[ph[31:21]];
        ph1 <= ph[31:16];
        shape1 <= a_ctrl[18:16];
        neg1 <= ph[31];                               // quadrants 2, 3: negative
        case (a_ctrl[18:16])
            3'd1: shp <= ph[31:16];
            3'd2: shp <= ~ph[31:16];
            3'd3: shp <= ph[31] ? ~ph[30:15] : ph[30:15];
            3'd4: shp <= {16{ph[31]}};
            3'd5: shp <= (ph < pw) ? 16'hFFFF : 16'h0000;
            default: shp <= 16'h0000;
        endcase
    end
    // stage 2: select; stage 3: MSB flip, out
    reg [15:0] w2 = 0, p2 = 0;
    always @(posedge clk) begin
        w2 <= (shape1 == 3'd0) ? (neg1 ? -srom : srom) :
              (shape1 == 3'd6) ? awg_q : shp;
        p2 <= ph1;
        wave_out <= w2 ^ {a_ctrl[19], 15'd0};
        phase_out <= p2;
    end

    // ---- register read (tables are write-only: read 0) ----------------------------------
    always @* begin
        if (raddr[13:8] != 6'h00)
            rdata = 0;
        else
            case (raddr[7:2])
                6'h00: rdata = s_pinc;
                6'h01: rdata = {15'd0, running, 4'd0, step, 7'd0, a_pinc[31]};
                6'h02: rdata = s_ctrl;
                6'h03: rdata = {8'd0, presc};
                6'h04: rdata = s_poff;
                6'h05: rdata = lstep;
                6'h06: rdata = fstep;
                6'h07: rdata = pw;
                6'h08: rdata = inc;
                6'h09: rdata = ph;
                6'h0A: rdata = 32'h444F5343;      // "DOSC"
                default: rdata = 0;
            endcase
    end
endmodule
