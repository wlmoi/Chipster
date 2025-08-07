/*
 * MODULE: user_logic_8bit_risc_peripheral
 *
 * DESCRIPTION:
 * This Verilog module implements a generic slave peripheral with a memory-mapped
 * register interface, suitable for connection to a processor bus like one found
 * in an 8-bit RISC-V or other simple RISC SoC.
 *
 * It contains 8 software-accessible registers (slv_reg0 to slv_reg7) that can be
 * written to and read from by a master (e.g., a CPU). The write operations
 * support byte-enables (BE) to allow for partial updates of the registers.
 *
 * This design is based on the logic patterns provided in the context, demonstrating
 * standard peripheral design techniques.
 *
 * PARAMETERS:
 *   C_SLV_DWIDTH : Width of the slave data bus (e.g., 32 bits).
 *   C_SLV_AWIDTH : Width of the slave address bus. A width of 5 is sufficient
 *                  to address 8 word-aligned registers (3 bits for selection,
 *                  2 bits for byte offset).
 *
 * PORT LIST:
 *   Bus2IP_Clk   : System clock.
 *   Bus2IP_Reset : System reset, active high.
 *   Bus2IP_Addr  : Address from the master to select a register.
 *   Bus2IP_Data  : Data from the master for write operations.
 *   Bus2IP_BE    : Byte enable signals for write operations.
 *   Bus2IP_WrCE  : Write Chip Enable - indicates a write cycle to one of the registers.
 *   Bus2IP_RdCE  : Read Chip Enable - indicates a read cycle from one of the registers.
 *   IP2Bus_Data  : Data sent from this peripheral to the master during a read.
 *   IP2Bus_Ack   : Acknowledge signal to the master, indicating completion.
 *
 */

module user_logic_8bit_risc_peripheral #(
    // Parameters
    parameter integer C_SLV_DWIDTH = 32,
    parameter integer C_SLV_AWIDTH = 5
)
(
    // Global signals
    input  wire                       Bus2IP_Clk,
    input  wire                       Bus2IP_Reset,

    // Bus interface signals
    input  wire [C_SLV_AWIDTH-1:0]    Bus2IP_Addr,
    input  wire [C_SLV_DWIDTH-1:0]    Bus2IP_Data,
    input  wire [C_SLV_DWIDTH/8-1:0]  Bus2IP_BE,
    input  wire                       Bus2IP_WrCE,
    input  wire                       Bus2IP_RdCE,
    output wire [C_SLV_DWIDTH-1:0]    IP2Bus_Data,
    output wire                       IP2Bus_Ack
);

    //----------------------------------------------------------------
    // Internal signal and register declarations
    //----------------------------------------------------------------

    // Slave registers - these are the memory-mapped registers
    reg [C_SLV_DWIDTH-1:0] slv_reg0;
    reg [C_SLV_DWIDTH-1:0] slv_reg1;
    reg [C_SLV_DWIDTH-1:0] slv_reg2;
    reg [C_SLV_DWIDTH-1:0] slv_reg3;
    reg [C_SLV_DWIDTH-1:0] slv_reg4;
    reg [C_SLV_DWIDTH-1:0] slv_reg5;
    reg [C_SLV_DWIDTH-1:0] slv_reg6;
    reg [C_SLV_DWIDTH-1:0] slv_reg7;

    // One-hot select signals for write and read operations
    wire [7:0] slv_reg_write_sel;
    wire [7:0] slv_reg_read_sel;

    // Output data register for read operations
    reg [C_SLV_DWIDTH-1:0] slv_read_mux_out;

    // Loop variables (for synthesizable for-loops)
    integer byte_index;

    //----------------------------------------------------------------
    // Address Decoding Logic
    //----------------------------------------------------------------
    // Decode the incoming address to generate one-hot select signals for
    // the target register. We assume registers are word-aligned, so we
    // inspect the address bits above the byte offset.
    // The select signal is generated as 8'b1000_0000 >> addr_index to match
    // the case statement structure from the provided source.
    assign slv_reg_write_sel = Bus2IP_WrCE ? (8'b10000000 >> Bus2IP_Addr[C_SLV_AWIDTH-1:2]) : 8'b0;
    assign slv_reg_read_sel  = Bus2IP_RdCE ? (8'b10000000 >> Bus2IP_Addr[C_SLV_AWIDTH-1:2]) : 8'b0;

    //----------------------------------------------------------------
    // Slave Register Write Logic
    //----------------------------------------------------------------
    // This block handles writing data from the bus to the slave registers.
    // It is sensitive to the clock edge and the active-high reset.
    always @(posedge Bus2IP_Clk)
    begin
      if (Bus2IP_Reset == 1'b1)
      begin
        // Reset all registers to zero
        slv_reg0 <= 0;
        slv_reg1 <= 0;
        slv_reg2 <= 0;
        slv_reg3 <= 0;
        slv_reg4 <= 0;
        slv_reg5 <= 0;
        slv_reg6 <= 0;
        slv_reg7 <= 0;
      end
      else
      begin
        // Use the one-hot write select to determine which register to update
        case (slv_reg_write_sel)
          8'b10000000: // Write to slv_reg0
            for (byte_index = 0; byte_index <= (C_SLV_DWIDTH/8)-1; byte_index = byte_index + 1)
              if (Bus2IP_BE[byte_index] == 1'b1)
                slv_reg0[byte_index*8 +: 8] <= Bus2IP_Data[byte_index*8 +: 8];

          8'b01000000: // Write to slv_reg1
            for (byte_index = 0; byte_index <= (C_SLV_DWIDTH/8)-1; byte_index = byte_index + 1)
              if (Bus2IP_BE[byte_index] == 1'b1)
                slv_reg1[byte_index*8 +: 8] <= Bus2IP_Data[byte_index*8 +: 8];

          8'b00100000: // Write to slv_reg2
            for (byte_index = 0; byte_index <= (C_SLV_DWIDTH/8)-1; byte_index = byte_index + 1)
              if (Bus2IP_BE[byte_index] == 1'b1)
                slv_reg2[byte_index*8 +: 8] <= Bus2IP_Data[byte_index*8 +: 8];

          8'b00010000: // Write to slv_reg3
            for (byte_index = 0; byte_index <= (C_SLV_DWIDTH/8)-1; byte_index = byte_index + 1)
              if (Bus2IP_BE[byte_index] == 1'b1)
                slv_reg3[byte_index*8 +: 8] <= Bus2IP_Data[byte_index*8 +: 8];

          8'b00001000: // Write to slv_reg4
            for (byte_index = 0; byte_index <= (C_SLV_DWIDTH/8)-1; byte_index = byte_index + 1)
              if (Bus2IP_BE[byte_index] == 1'b1)
                slv_reg4[byte_index*8 +: 8] <= Bus2IP_Data[byte_index*8 +: 8];

          8'b00000100: // Write to slv_reg5
            for (byte_index = 0; byte_index <= (C_SLV_DWIDTH/8)-1; byte_index = byte_index + 1)
              if (Bus2IP_BE[byte_index] == 1'b1)
                slv_reg5[byte_index*8 +: 8] <= Bus2IP_Data[byte_index*8 +: 8];

          8'b00000010: // Write to slv_reg6
            for (byte_index = 0; byte_index <= (C_SLV_DWIDTH/8)-1; byte_index = byte_index + 1)
              if (Bus2IP_BE[byte_index] == 1'b1)
                slv_reg6[byte_index*8 +: 8] <= Bus2IP_Data[byte_index*8 +: 8];

          8'b00000001: // Write to slv_reg7
            for (byte_index = 0; byte_index <= (C_SLV_DWIDTH/8)-1; byte_index = byte_index + 1)
              if (Bus2IP_BE[byte_index] == 1'b1)
                slv_reg7[byte_index*8 +: 8] <= Bus2IP_Data[byte_index*8 +: 8];

          default: ; // No write operation
        endcase
      end
    end

    //----------------------------------------------------------------
    // Slave Register Read Logic
    //----------------------------------------------------------------
    // This block handles reading data from the slave registers and placing
    // it on the output data bus. It is a combinational multiplexer.
    always @(*)
    begin
      // Default to zero
      slv_read_mux_out = {C_SLV_DWIDTH{1'b0}};

      // Use the one-hot read select to choose which register's data to output
      case (slv_reg_read_sel)
        8'b10000000: slv_read_mux_out = slv_reg0;
        8'b01000000: slv_read_mux_out = slv_reg1;
        8'b00100000: slv_read_mux_out = slv_reg2;
        8'b00010000: slv_read_mux_out = slv_reg3;
        8'b00001000: slv_read_mux_out = slv_reg4;
        8'b00000100: slv_read_mux_out = slv_reg5;
        8'b00000010: slv_read_mux_out = slv_reg6;
        8'b00000001: slv_read_mux_out = slv_reg7;
        default:     slv_read_mux_out = {C_SLV_DWIDTH{1'b0}};
      endcase
    end

    // Assign the multiplexer output to the bus
    assign IP2Bus_Data = slv_read_mux_out;

    //----------------------------------------------------------------
    // Acknowledge Logic
    //----------------------------------------------------------------
    // Generate a single-cycle acknowledge signal to the master when a
    // valid read or write operation is detected.
    assign IP2Bus_Ack = Bus2IP_WrCE | Bus2IP_RdCE;

endmodule