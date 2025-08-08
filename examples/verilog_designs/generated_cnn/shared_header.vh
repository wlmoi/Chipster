//==============================================================================
// Defines and Parameters
//==============================================================================

// Data bit widths
`define DATA_WIDTH 8
`define WEIGHT_WIDTH 8
`define BIAS_WIDTH 16
`define ACCUM_WIDTH 24

// Input Image Dimensions (e.g., for MNIST-like data)
`define IMG_WIDTH 28
`define IMG_HEIGHT 28
`define IMG_SIZE (`IMG_WIDTH * `IMG_HEIGHT)
`define IMG_ADDR_WIDTH $clog2(`IMG_SIZE)

// Kernel Dimensions
`define KERNEL_SIZE 3
`define KERNEL_AREA (`KERNEL_SIZE * `KERNEL_SIZE)
`define KERNEL_ADDR_WIDTH $clog2(`KERNEL_AREA)

// Convolution Output Dimensions (no padding, stride 1)
`define CONV_OUT_WIDTH (`IMG_WIDTH - `KERNEL_SIZE + 1)
`define CONV_OUT_HEIGHT (`IMG_HEIGHT - `KERNEL_SIZE + 1)
`define CONV_OUT_AREA (`CONV_OUT_WIDTH * `CONV_OUT_HEIGHT)
`define CONV_OUT_ADDR_WIDTH $clog2(`CONV_OUT_AREA)

// Max Pooling Output Dimensions (no padding, stride = POOL_SIZE)
`define POOL_SIZE 2
`define POOL_AREA (`POOL_SIZE * `POOL_SIZE)
`define POOL_OUT_WIDTH (`CONV_OUT_WIDTH / `POOL_SIZE)
`define POOL_OUT_HEIGHT (`CONV_OUT_HEIGHT / `POOL_SIZE)
`define POOL_OUT_AREA (`POOL_OUT_WIDTH * `POOL_OUT_HEIGHT)
`define POOL_OUT_ADDR_WIDTH $clog2(`POOL_OUT_AREA)
