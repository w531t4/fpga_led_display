


`timescale 1ns / 1ns


  `define test1 1
  `define test2 1
//  `define test3 1
 `define test4 1
 `define test5 1


module tbtest;



  parameter 	NumberOfReads  = 2;
  parameter 	NumberOfWrites = 1;
  parameter	SeparateReadWriteAddress = 0;


  parameter	 DATAWIDTH = 256;
  parameter	 ADDRWIDTH = 16;
  parameter	 MEMDEPTH = 2**(ADDRWIDTH);


  parameter	 PERIOD_A = 50;
  parameter	 PERIOD_B = 75;


  parameter	 LATENCY = 2;
  parameter	 ITER  = 20;
  parameter 	 DELAY = 10;



  wire 				PortAClk;
  reg  [ADDRWIDTH-1:0] 		PortAAddr;
  reg  [DATAWIDTH-1:0] 		PortADataIn;



  wire [DATAWIDTH-1:0] 		PortADataOut_rtl, PortADataOut_synth;


  reg 				PortAWriteEnable;
  reg 				PortAReadEnable;
  reg 				PortAReset;



  wire 				PortBClk;
  reg  [ADDRWIDTH-1:0] 		PortBAddr;
  reg  [DATAWIDTH-1:0] 		PortBDataIn;


  wire [DATAWIDTH-1:0] 		PortBDataOut_rtl, PortBDataOut_synth;


  reg 				PortBWriteEnable;
  reg 				PortBReadEnable;
  reg 				PortBReset;


  integer tb_log;
  integer NumOfErrs;
  integer i, j, k, m, n, p;
  integer test_probe;


  reg clk1;
  reg clk2;


  reg [ADDRWIDTH-1:0] StoreAddrA [ITER:0] ;
  reg [ADDRWIDTH-1:0] StoreAddrB [ITER:0] ;



// task definitions


//Compare Data


 task CompareDataA;
   integer m;
   begin


     for (m=0; m < LATENCY; m = m + 1)
      begin
         @(negedge PortAClk);
      end


   #(DELAY);


     if(PortADataOut_rtl != PortADataOut_synth)
        begin
	  NumOfErrs = NumOfErrs + 1;
  	  $fdisplay(tb_log, "PortAAddr = %h, PortADataOut_rtl = %h,  PortADataOut_synth = %h, <---- ERROR",
   	       		PortAAddr, PortADataOut_rtl, PortADataOut_synth);
        end
    end
 endtask


 task CompareDataB;
   integer p;
  begin


    for (p=0; p < LATENCY; p = p + 1)
      begin
   	@(negedge PortBClk);
      end


  #(DELAY);


     if(PortBDataOut_rtl != PortBDataOut_synth)
        begin
	  NumOfErrs = NumOfErrs + 1;
  	  $fdisplay(tb_log, "PortBAddr = %h, PortBDataOut_rtl = %h,  PortBDataOut_synth = %h, <---- ERROR",
   	       		PortBAddr, PortBDataOut_rtl, PortBDataOut_synth);
        end
    end
 endtask



// RTL Instanitation


newram_rtl DUT_RTL (
	  .PortAClk(PortAClk)
	, .PortAAddr(PortAAddr)
	, .PortADataIn(PortADataIn)
	, .PortADataOut(PortADataOut_rtl)
	, .PortAWriteEnable(PortAWriteEnable)
	, .PortAReset(PortAReset)


	, .PortBClk(PortBClk)
	, .PortBDataIn(PortBDataIn)
	, .PortBAddr(PortBAddr)
	, .PortBWriteEnable(PortBWriteEnable)
	, .PortBDataOut(PortBDataOut_rtl)
	, .PortBReset(PortBReset)


	);



//Netlits Instantiation


newram	 DUT_synth (
	  .PortAClk(PortAClk)
	, .PortAAddr(PortAAddr)
	, .PortADataIn(PortADataIn)
	, .PortADataOut(PortADataOut_synth)
	, .PortAWriteEnable(PortAWriteEnable)
	, .PortAReset(PortAReset)


	, .PortBClk(PortBClk)
	, .PortBDataIn(PortBDataIn)
	, .PortBAddr(PortBAddr)
	, .PortBWriteEnable(PortBWriteEnable)
	, .PortBDataOut(PortBDataOut_synth)
	, .PortBReset(PortBReset)


	);



 initial clk1 = 1'b1;
 always #(PERIOD_A / 2)  clk1 = ~clk1;


 initial clk2 = 1'b1;
 always #(PERIOD_B / 2)  clk2 = ~clk2;


 // If same clock, make it all clk1
  assign PortAClk = clk1;
  assign PortBClk = clk1; //clk2


  initial
   begin
 	tb_log 		 = $fopen("tb.log");
 	NumOfErrs	 = 0;


 // Initialize all the input ports

 	PortAAddr 	 = 'd0;
 	PortADataIn	 = 'd0;
 	PortAWriteEnable = 1'b0;
 	PortAReadEnable	 = 1'b0;
 	PortAReset	 = 1'b0;


 	PortBAddr 	 = 'd0;
	PortBDataIn	 = 'd0;
	PortBWriteEnable = 1'b0;
	PortBReadEnable	 = 1'b0;
 	PortBReset	 = 1'b0;


   end



 initial
  begin


  test_probe = 0;
  @(negedge PortAClk);
  @(negedge PortAClk);
  @(negedge PortBClk);
  @(negedge PortBClk);


  `ifdef test1


   // Test scenario: 1
   // Write into ports A & B at random addresses one after the another
   // and read back the contents



   // PortA Write
     for (i= 0; i < ITER; i = i + 1)
	begin


	     PortAWriteEnable = 1'b1;
	     PortAReadEnable  = 1'b0;
	     PortAAddr  = $random;
	     PortADataIn = $random;
	     StoreAddrA[i]  = PortAAddr;


	    @(negedge PortAClk);

	     PortAWriteEnable = 1'b0;
    	end

  	@(negedge PortAClk);

     // PortB Write
       for (j= 0; j < ITER; j = j + 1)
  	begin

  	     PortBWriteEnable 	= 1'b1;
	     PortBReadEnable  	= 1'b0;
  	     PortBAddr  = $random;
  	     PortBDataIn = $random;
  	     StoreAddrB[j]  = PortBAddr;

  	    @(negedge PortBClk);  // No Latency required I guess

  	    PortBWriteEnable = 1'b0;
    	end



  // PortA Read
       for (k= 0; k < ITER; k = k + 1)
  	begin

  	     PortAWriteEnable 	= 1'b0;
  	     PortAReadEnable  	= 1'b1;
  	     PortAAddr  	= StoreAddrA[k];

  	   CompareDataA;

      	end

    // PortB Read
       for (n= 0; n < ITER; n = n + 1)
    	begin

    	     PortBWriteEnable 	= 1'b0;
    	     PortBReadEnable  	= 1'b1;
    	     PortBAddr 		= StoreAddrB[n];

	    CompareDataB;

  	end

  test_probe = 1;

 `endif

`ifdef test2

  // Test scenario: 2 --> Enable this only when Output port is registered
     // Write into ports A & B at random addresses simultaneously
     // and read back the contents

   fork : test2Write
    // PortA Write
       for (i= 0; i < ITER; i = i + 1)
  	begin


  	     PortAWriteEnable 	= 1'b1;
  	     PortAReadEnable  	= 1'b0;
  	     PortAAddr  	= $random;
  	     PortADataIn 	= $random;
  	     StoreAddrA[i]  	= PortAAddr;

  	    @(negedge PortAClk);
      	end

    // What happens when the address clash ??

       // PortB Write
         for (j= 0; j < ITER; j = j + 1)
    	begin


    	     PortBWriteEnable 	= 1'b1;
    	     PortBReadEnable  	= 1'b0;
    	     PortBAddr  	= $random;
    	     PortBDataIn 	= $random;
    	     StoreAddrB[j]  	= PortBAddr;

    	    @(negedge PortBClk);  // No Latency required I guess
      	end

   join // end test2Write


   fork : test2Read
    // PortA Read
         for (k= 0; k < ITER; k = k + 1)
    	begin


  	     PortAWriteEnable 	= 1'b0;
  	     PortAReadEnable  	= 1'b1;
  	     PortAAddr  	= StoreAddrA[k];

		CompareDataA;
        end


      // PortB Read
         for (n= 0; n < ITER; n = n + 1)
      	begin

    	     PortBWriteEnable 	= 1'b0;
    	     PortBReadEnable  	= 1'b1;
    	     PortBAddr 		= StoreAddrB[n];

		CompareDataB;

    	end

  join // end test2Read

  test_probe = 2;

 `endif // creating lots of problems with memeory contention in Simulations


 `ifdef test3


  // Test scenario: 3
    // Write into port A & Read from B at random addresses & vice versa

   // PortA Write PortB Read
       for (i= 0; i < ITER; i = i + 1)
  	begin

  	     PortAWriteEnable = 1'b1;
  	     PortAReadEnable  = 1'b0;
  	     PortAAddr  = $random;
  	     PortADataIn = $random;
  	     StoreAddrA[i]  = PortAAddr;

  	    @(negedge PortAClk);
            @(negedge PortBClk);

	     PortBWriteEnable 	= 1'b0;
	     PortBReadEnable  	= 1'b1;
	     PortBAddr 		= StoreAddrA[i];

       	   CompareDataB;

  	end


    // PortB Write PortA Read
      for (j= 0; j < ITER; j = j + 1)
    	begin

    	     PortBWriteEnable = 1'b1;
    	     PortBReadEnable  	= 1'b0;
    	     PortBAddr  = $random;
    	     PortBDataIn = $random;
    	     StoreAddrB[j]  = PortBAddr;

    	    @(negedge PortBClk);  // No Latency required I guess
      	    @(negedge PortAClk);

    	     PortAWriteEnable 	= 1'b0;
    	     PortAReadEnable  	= 1'b1;
    	     PortAAddr  	= StoreAddrB[j];

	CompareDataA;

        end

 test_probe = 3;

  `endif

 `ifdef test4

// Test scenario: 4
    // Read & Write into same port simultaneously (Checking the Write_modes)

   // PortA Write PortA Read
       for (i= 0; i < ITER; i = i + 1)
  	begin

  	     PortAWriteEnable = 1'b1;
  	     PortAReadEnable  	= 1'b1;
  	     PortAAddr  = $random;
  	     PortADataIn = $random;
  	     StoreAddrA[i]  = PortAAddr;

       	   CompareDataA;

  	end

   // PortB Write PortB Read
       for (i= 0; i < ITER; i = i + 1)
  	begin

  	     PortBWriteEnable = 1'b1;
  	     PortBReadEnable  	= 1'b1;
  	     PortBAddr  = $random;
  	     PortBDataIn = $random;
  	     StoreAddrB[i]  = PortBAddr;

       	   CompareDataB;

  	end


test_probe = 4;

 `endif

 `ifdef test5

// Test scenario: 5
    // Test Reset conditions.
    // Read & Write into same port simultaneously (Checking the Write_modes)

   // PortA Write PortA Read
       for (i= 0; i < ITER; i = i + 1)
  	begin

  	    PortAReset	 = 1'b1;

  	     PortAWriteEnable = 1'b1;
  	     PortAReadEnable  	= 1'b1;
  	     PortAAddr  = $random;
  	     PortADataIn = $random;
  	     StoreAddrA[i]  = PortAAddr;

       	   CompareDataA;

  	end

   // PortB Write PortB Read
       for (i= 0; i < ITER; i = i + 1)
  	begin

     	    PortBReset	 = 1'b1;

  	    @(negedge PortBClk);
  	    @(negedge PortBClk);

  	     PortBWriteEnable = 1'b1;
  	     PortBReadEnable  	= 1'b1;
  	     PortBAddr  = $random;
  	     PortBDataIn = $random;
  	     StoreAddrB[i]  = PortBAddr;

       	   CompareDataB;

  	end


	PortAReset	 = 1'b0;
	PortBReset	 = 1'b0;

test_probe = 5;

 `endif

/// Check for Any Errors

  	if (NumOfErrs == 0)
	  $display("Simulation Successful !!! ");
   	else
   	 $display("Simulation FAILED !!! ");



		$fclose(tb_log);

		$finish;



  end //INITIAL



 initial
  begin
   $dumpfile ("dump.vcd");
   $dumpvars (0, tbtest);
  end



endmodule
