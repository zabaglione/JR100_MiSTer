//============================================================================
//
//  JR-100 auto-typer (JR100_MiSTer).
//
//  Types RUN or A=USR($hhhh) on the key matrix after a program load,
//  exactly as a user would. Key positions and the shift pairs come
//  from the BASIC ROM's keyboard decode tables ($FA6C normal, $FA99
//  shifted): '=' is Shift+'-', '(' Shift+8, ')' Shift+9, '$' Shift+4.
//
//  Cadence: each key is held ~0.1s with a ~0.1s gap, slower than the
//  ROM's per-key click (which pauses the keyboard scan) - the same
//  timing the ROM-driven cassette tests established.
//
//  Copyright (C) 2026 Zabaglione
//  SPDX-License-Identifier: GPL-2.0-or-later
//
//============================================================================

module jr100_autotype
(
    input  logic        clk,
    input  logic        rst,
    input  logic        cen,          // CPU-rate clock enable

    input  logic        start,        // one-clk pulse
    input  logic        mode_usr,     // 0: RUN  1: A=USR($hhhh)
    input  logic [15:0] usr_addr,

    output logic [44:0] key_overlay,
    output logic        busy
);

    // A file load may complete before JR-BASIC has reached its input loop.
    // Wait long enough for boot and the first keyboard scan; otherwise the
    // leading characters can be discarded while the READY prompt is drawn.
    localparam int T_DELAY = 1500000; // settle after load (~1.68s)
    localparam int T_PRESS = 90000;   // key held (~0.1s)
    localparam int T_GAP   = 90000;   // all released between keys

    localparam logic [5:0] K_SHIFT = 6'd1;    // (0,1)
    localparam logic [5:0] K_CR    = 6'd43;   // (8,3)

    // matrix bit index for a hex digit 0-F (letters per the normal table)
    function automatic logic [5:0] hex_key(input logic [3:0] d);
        case (d)
            4'h0: hex_key = 6'd24;                       // (4,4)
            4'h1, 4'h2, 4'h3, 4'h4, 4'h5:
                  hex_key = 6'd15 + {2'b0, d} - 6'd1;    // (3,0)-(3,4)
            4'h6, 4'h7, 4'h8, 4'h9:
                  hex_key = 6'd20 + {2'b0, d} - 6'd6;    // (4,0)-(4,3)
            4'hA: hex_key = 6'd5;                        // A (1,0)
            4'hB: hex_key = 6'd36;                       // B (7,1)
            4'hC: hex_key = 6'd4;                        // C (0,4)
            4'hD: hex_key = 6'd7;                        // D (1,2)
            4'hE: hex_key = 6'd12;                       // E (2,2)
            default: hex_key = 6'd8;                     // F (1,3)
        endcase
    endfunction

    // step -> {shift, key index}; RUN uses steps 0-3, USR steps 0-12
    function automatic logic [6:0] step_key(input logic       usr,
                                            input logic [3:0] step,
                                            input logic [15:0] addr);
        if (!usr) begin
            case (step)
                4'd0: step_key = {1'b0, 6'd13};          // R (2,3)
                4'd1: step_key = {1'b0, 6'd26};          // U (5,1)
                4'd2: step_key = {1'b0, 6'd37};          // N (7,2)
                default: step_key = {1'b0, K_CR};
            endcase
        end else begin
            case (step)
                4'd0:  step_key = {1'b0, 6'd5};          // A (1,0)
                4'd1:  step_key = {1'b1, 6'd44};         // = : Shift+'-'
                4'd2:  step_key = {1'b0, 6'd26};         // U
                4'd3:  step_key = {1'b0, 6'd6};          // S (1,1)
                4'd4:  step_key = {1'b0, 6'd13};         // R
                4'd5:  step_key = {1'b1, 6'd22};         // ( : Shift+8
                4'd6:  step_key = {1'b1, 6'd18};         // $ : Shift+4
                4'd7:  step_key = {1'b0, hex_key(addr[15:12])};
                4'd8:  step_key = {1'b0, hex_key(addr[11:8])};
                4'd9:  step_key = {1'b0, hex_key(addr[7:4])};
                4'd10: step_key = {1'b0, hex_key(addr[3:0])};
                4'd11: step_key = {1'b1, 6'd23};         // ) : Shift+9
                default: step_key = {1'b0, K_CR};
            endcase
        end
    endfunction

    typedef enum logic [1:0] { A_IDLE, A_DELAY, A_PRESS, A_GAP } astate_t;

    astate_t     state /* verilator public_flat_rd */;
    logic        usr_mode;
    logic [15:0] addr;
    logic [3:0]  step, last_step;
    logic [20:0] cnt;

    assign busy = (state != A_IDLE);

    // Shift must be down before the character key appears: the ROM
    // scans row 0 (shift) first, so a simultaneous press can be decoded
    // unshifted. Hold shift through the gap preceding a shifted key.
    always_comb begin
        logic [6:0] k, k_next;
        k      = step_key(usr_mode, step, addr);
        k_next = step_key(usr_mode, step + 4'd1, addr);
        key_overlay = '0;
        if (state == A_PRESS) begin
            key_overlay[k[5:0]] = 1'b1;
            if (k[6]) key_overlay[K_SHIFT] = 1'b1;
        end else if (state == A_GAP && step != last_step && k_next[6]) begin
            key_overlay[K_SHIFT] = 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= A_IDLE;
        end else begin
            unique case (state)
            A_IDLE: begin
                if (start) begin
                    usr_mode  <= mode_usr;
                    addr      <= usr_addr;
                    step      <= 4'd0;
                    last_step <= mode_usr ? 4'd12 : 4'd3;
                    cnt       <= 21'(T_DELAY);
                    state     <= A_DELAY;
                end
            end
            A_DELAY: if (cen) begin
                if (cnt != 0) cnt <= cnt - 21'd1;
                else begin
                    cnt   <= 21'(T_PRESS);
                    state <= A_PRESS;
                end
            end
            A_PRESS: if (cen) begin
                if (cnt != 0) cnt <= cnt - 21'd1;
                else begin
                    cnt   <= 21'(T_GAP);
                    state <= A_GAP;
                end
            end
            A_GAP: if (cen) begin
                if (cnt != 0) cnt <= cnt - 21'd1;
                else if (step == last_step) begin
                    state <= A_IDLE;
                end else begin
                    step  <= step + 4'd1;
                    cnt   <= 21'(T_PRESS);
                    state <= A_PRESS;
                end
            end
            default: state <= A_IDLE;
            endcase
        end
    end

endmodule
