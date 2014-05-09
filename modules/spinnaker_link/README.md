Asynchronous 2-of-7 SpiNNaker Link Interface
============================================

A pair of modules which provide communication to and from the asynchronous,
2-of-7 coded SpiNNaker chip-to-chip links and the standard vld/rdy signals used
by other spI/O modules.

A high-level overview of the modules are is shown below:

	              SpiNNaker Link Receiver
	              ```````````````````````
	    ,--------,             ,--------,
	    |        |             |        | data[71:0]  
	    |        |  2of7[6:0]  | SpiNN- |======/=====>
	    | SpiNN- |======/=====>| aker   |
	    | aker   |             | Link   |     vld
	    | Chip   |     ack     | Recei- |------------>
	    |        |<------------| ver    |
	    |        |             |        |     rdy
	    |        |             |   /\   |<------------
	    '--------'             '--'--`--'
	                               |
	                       clk ----+------------------...
	
	
	                SpiNNaker Link Sender
	                `````````````````````
	    ,--------,             ,--------,
	    |        |             |        | data[71:0]  
	    |        |  2of7[6:0]  | SpiNN- |<=====/======
	    | SpiNN- |<=====/======| aker   |
	    | aker   |             | Link   |     vld
	    | Chip   |     ack     | Recei- |<------------
	    |        |------------>| ver    |
	    |        |             |        |     rdy
	    |        |             |   /\   |------------>
	    '--------'             '--'--`--'
	                               |
	                       clk ----+------------------...

Authors
-------

This module is taken straight from the 'SpiNNlink' project which provides the
connectivity between boards in large SpiNNaker systems. It was written by Luis
Plana, based on work by Jeff Pepper.