/*
 * Shared parameters for the FIR filter design.
 */

`timescale 1ns / 1ps

// Width of the input data
`define IWIDTH 16
// Width of the output data
`define OWIDTH 16
// Width of the filter coefficients
`define COEFWIDTH 16
// Number of taps in the filter
`define NTAPS 11