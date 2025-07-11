        module PDPW16KD (
	input DI35, DI34, DI33, DI32, DI31, DI30, DI29, DI28, DI27, DI26, DI25, DI24, DI23, DI22, DI21, DI20, DI19, DI18,
	input DI17, DI16, DI15, DI14, DI13, DI12, DI11, DI10, DI9, DI8, DI7, DI6, DI5, DI4, DI3, DI2, DI1, DI0,
	input ADW8, ADW7, ADW6, ADW5, ADW4, ADW3, ADW2, ADW1, ADW0,
	input BE3,  BE2,  BE1, BE0, CEW, CLKW, CSW2, CSW1, CSW0,
	input ADR13, ADR12, ADR11, ADR10, ADR9, ADR8, ADR7, ADR6, ADR5, ADR4, ADR3, ADR2, ADR1, ADR0,
	input CER, OCER, CLKR, CSR2, CSR1, CSR0, RST,
	output DO35, DO34, DO33, DO32, DO31, DO30, DO29, DO28, DO27, DO26, DO25, DO24, DO23, DO22, DO21, DO20, DO19, DO18,
	output DO17, DO16, DO15, DO14, DO13, DO12, DO11, DO10, DO9, DO8, DO7, DO6, DO5, DO4, DO3, DO2, DO1, DO0
);
        */
        // RAM_DP_TRUE <-- too much
        // Pseudo Dual-Port RAM (RAM_DP) – EBR Based <-- we want this -
        // primitive name = PDPW16KD (page 26)
        //  8192 x 2 ([1:0], and [12:0])
        //      ADW - WrAddress
        //      DI  - Write Data
        //      CLKW - WrClock
        //      CEW - WE
        ///      RST - Reset
        //      CSW -
        //      ADR - RdAddress
        //      DO - Read Data
        //      CLKR - RdClock
        //      CER - RdClockEn
        //      OCER - ? ReadOutputClockEnable
        //      CSR - ?
        // 8192x2 Addresses:13bits, data:2bits