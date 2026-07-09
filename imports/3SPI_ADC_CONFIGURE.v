

//С��˸���?3�߸���ADC����ͨ��SPI�����ļ���������?ϰ��

//΢�Ź��ںţ�С��˸��ĺ�г����?лл֧�֣�

//���ں������и�Ϊ��ϸ�Ľ��ܣ�ѧϰ�ͽ����빫�ں�˽��С��˸�磡
//////////////////////////////////////////////////////////////////////////////////
module ADC_CONFIGURE(
	input		CLK		,  	//ϵͳ����ʱ�ӡ�20MHz
	input		reset	,	//ϵͳͬ����λ
	input image_en,
	input spi_en,
	// output	reg ADC_RST	,	//to ADC
	output	reg sclk	,	//to ADC
	output	reg cs_b	,	//to ADC
	input 	 	sdin	,	//to FPGA
	output	reg sdout	,	//to ADC
	output	reg CfgDone	,	//���óɹ�����1
	output  reg Tri_en		//FPGA ��̬�����ź�
    );
	
	
///////////////////////////////////////////////////////	
	localparam	Wr_n		=	8'd4;	//������3���Ĵ���Ϊ��		
	wire	[23:00]	WriteReg1;
	wire	[23:00]	WriteReg2;
	wire	[23:00]	WriteReg3;
	wire	[23:00]	WriteReg4;
	wire	[23:00]	WriteReg5;

	// assign 	WriteReg1		= {3'b000,13'h008,8'h03}		;//
    // assign 	WriteReg2		= {3'b000,13'h109,8'h03}		;//
	// assign 	WriteReg3		= {3'b000,13'h109,8'h03};//	
	// assign 	WriteReg4		= {3'b000,13'h00d,8'h04};//	
	// assign 	WriteReg5		= {3'b000,13'h00d,8'h00}		;//
	assign 	WriteReg1		= {3'b000,13'h000,8'h3c}		;//all registers revert to default
    assign 	WriteReg2		= {3'b000,13'h015,8'h30}		;//100ou
	assign 	WriteReg3		= {3'b000,13'h109,8'h00};//	  50 14bit 20MSPS  52 14bit 40MSPS
	assign 	WriteReg4		= {3'b000,13'h008,8'h00};//	  Set resolution/sample rate override
	// assign 	WriteReg3		= {3'b000,13'h100,8'h50};//	  50 14bit 20MSPS  52 14bit 40MSPS
	// assign 	WriteReg4		= {3'b000,13'h0ff,8'h01};//	  Set resolution/sample rate override
	assign 	WriteReg5		= {3'b000,13'h00d,8'h00}		;//off 00    output test mode 0/1 09
///////////////////////////////////////////////////////	    
	localparam	Rd_n			=	8'd4;//�Զ�3���Ĵ�����ֵΪ��
	wire	[23:0]	RdAddr1;
	 wire	[23:0]	RdAddr2;
	wire	[23:0]	RdAddr3;
	wire	[23:0]	RdAddr4;
	assign 	RdAddr1	= 24'h80_08_FF		;//Ĭ��99Ϊ����ģʽ��BDΪ�Ը�λģʽ��
	assign 	RdAddr2	= 24'h80_0d_FF		;//chip ID��0x29	
	assign 	RdAddr3	= 24'h80_00_FF		;//0X01
	assign 	RdAddr4	= 24'h81_09_FF		;//0X01
///////////////////////////////////////////////////////	
                                          
(*mark_debug = "true"*)	reg			[7:0]	RdData1;//�洢��ȡ��3���Ĵ�����ֵ
(*mark_debug = "true"*)	reg			[7:0]	RdData2;
(*mark_debug = "true"*)	reg			[7:0]	RdData3;
(*mark_debug = "true"*)	reg			[7:0]	RdData4;
//////////////////////////////////////////////////////////////////////////////////////////////	
	
		
//////////////////////////////////////////////////////////////////////////////////////////////	                                       
(*mark_debug = "true"*)		reg	[7:0] 	state;                     
		reg	[21:0]	cnt;                       
	reg	[7:0]	n; //���д�ļĴ����ڵڼ���?                      
	reg	[7:0]	m; //��Ƕ��ļĴ����ڵڼ���?  

	always @(posedge CLK or negedge reset)               
		if(~reset)                          
			begin                          
			state	<=8'd16;
			cs_b	<=1'b1;
			sdout	<=1'b1;
			sclk	<=1'b1;
			CfgDone	<=1'b0;
			cnt		<=22'd23;

			n			<=8'd0;
			m			<=8'd0;
			RdData1		<=8'd0;
			RdData2		<=8'd0;
			RdData3		<=8'd0;
			RdData4     <= 0;
			Tri_en  <=1'b1;//��Ϊ1ʱ������ΪsdioΪ���?
			end
		else case(state)
		8'd16:	begin	         
					if(cnt==22'd0)//�ⲿ��λ�󣬵ȴ�15��ʱ�����ڣ�ʹ���ȶ��ٽ���ADC�Ĵ�������
						begin
						state	<=8'd0;
						cnt		<=22'd23;
						end
					else
						begin
						cnt		<=cnt-1'b1;
						state	<=8'd16;

						Tri_en  <=1'b1;
						end		
				end
		8'd0:	begin//��ʼ�����еļĴ�����ʼֵ
					cs_b		<=1'b1;
					sdout		<=1'b1;
					sclk		<=1'b1;
					cnt			<=22'd23;
					n			<=8'd1;
					m			<=8'd1;
					
					CfgDone 	<=1'b0;
					RdData1		<=8'd0;
					RdData2		<=8'd0;
					RdData3		<=8'd0;
					Tri_en  	<=1'b1;
					if(spi_en)
					state		<=8'd1;
					else
						state		<=8'd0;
				end
		8'd1:	begin//д��24bit�Ĵ������ݵ�MSB
					cs_b	<=1'b0;
					sclk	<=1'b0;
					if(n==8'd1)
						sdout	<=WriteReg1[cnt];
					else if(n==8'd2)
						sdout	<=WriteReg2[cnt];
					else if(n==8'd3)
						sdout	<=WriteReg3[cnt];
					else if(n==8'd4)
						sdout	<=WriteReg4[cnt];
					else if(n==8'd5)
						sdout	<=WriteReg5[cnt];	
					state	<=8'd2;
				end
		8'd2:	begin//ѭ��24�Σ����?24bit���ݵĴӸߵ���д��
					sclk	<=1'b1;
					if(cnt==22'd0)
						begin
						state<=8'd3;
						cnt	<=22'd23;
						end
					else
						begin
						cnt	<=cnt-1'b1;
						state	<=8'd1;
						end		
				end
		8'd3:	begin//д��һ��24bit���ݺ󣬵ȴ�24��ʱ�������ٿ�ʼ��һ��״̬
					if(cnt==22'd0)
						begin
						state<=8'd4;
						cnt	<=22'd23;
						end
					else
						begin
						cnt	<=cnt-1'b1;
						cs_b	<=1'b1;
						sclk	<=1'b1;
						sdout	<=1'b1;
						state	<=8'd3;
						end		
				end	
		8'd4:	begin//���nֵ������n�����趨���������ݸ������������¸�״̬������ѭ��д��
					if(n==Wr_n||n==5)//n==Wr_n ||
						begin
						state<=8'd7;//ѭ����д��ϣ���ʼ��һ������?
						n<=8'd1;
						cnt<=22'd23;
						end
					// else if(image_en)begin
					// 	n <= 5;
					// 	state <= 1;
					// end
					else if(n < Wr_n)
						begin
						n		<=n+1;
						state	<=8'd1;//����״̬1ѭ��д
						end
				end
///////////////////////////////////////////////////////////////���д����?////////////////////////////						
		8'd7:	begin//�ȴ�23��ʱ�����ں��ٽ�����һ������
				if(cnt==22'd0)
					begin
					state<=8'd8;//
					cnt	<=22'd23;
					end
				else
					begin
					cnt	<=cnt-1'b1;
					state	<=8'd7;
					end
				end
////////////////////////////////////////////////////////////////////////////////////				
		8'd8:	begin//��ʼ����������д��3λ����+13λ��ַ
					cs_b	<=1'b0;
					sclk	<=1'b0;
					Tri_en  	<=1'b1;
					if(m==8'd1)
						sdout	<=RdAddr1[cnt];
					else if(m==8'd2)
						sdout	<=RdAddr2[cnt];
					else if(m==8'd3)
						sdout	<=RdAddr3[cnt];
					else if(m==8'd4)
						sdout	<=RdAddr4[cnt];
			
					state	<=8'd9;	
				end		
		8'd9:	begin//ѭ��д��ֱ��д��16bit�����һ��sclk��������д���?0bit��ַ
					sclk	<=1'b1;
					if(cnt==22'd8)//������Ҫע�����cntΪ8ʱ��16bitд�꣬�ڽ�����sclk���½���ADC��ʼ����Ĵ������ݣ���ʱFPGA
						begin	//����̬����Ҫ��Ϊ������ʵ�����ݽ���
						state<=8'd10;//��������?
						cnt		<=22'd7;//����cntҪ��ֵΪ7����Ϊ������adc�����?8bit����ֻ��Ҫ����7����λ���ɡ�
						end
					else
						begin
						cnt	<=cnt-1'b1;
						state	<=8'd8;
						end
				end	
		8'd10:	begin//��sclk�½��أ���̬��Ϊ����
					sclk	<=1'b0;//�½���ADC�������ݿ�ʼ�����FPGA��sclk������ȡ�������ȶ�
					cs_b	<=1'b0;
					Tri_en  <=1'b0;//��̬ת��
					state	<=8'd11;
					
				end	
		8'd11:	begin//��sclk�����أ���ʼȡ��
					
					sclk	<=1'b1;
					
					if(cnt==22'd0)//8bit����
						begin
						state<=8'd12;//��������?
						end
					else
						begin
						cnt	<=cnt-1'b1;
						state	<=8'd10;
						end
						
					if((cnt<=22'd7)&&m==8'd1) //��cntΪ7ʱ��������д��16bit�Ķ����ƺ͵�ַ��
						begin		//�õ�ַ�����ݽ��ڽ�����8��clk���?	
							RdData1	<={RdData1[6:0],sdin};//��λ�Ĵ���ȡ����������
						end		
					if((cnt<=22'd7)&&m==8'd2) 
						begin		
							RdData2	<={RdData2[6:0],sdin};
						end	
					if((cnt<=22'd7)&&m==8'd3) 
						begin		
							RdData3	<={RdData3[6:0],sdin};
						end	
					if((cnt<=22'd7)&&m==8'd4) 
						begin		
							RdData4	<={RdData4[6:0],sdin};
						end	
				end	

				
		8'd12:	begin//��һ�������?
					sclk	<=1'b1;
					cs_b	<=1'b1;
					state	<=8'd13;
					cnt		<=22'd23;
				end				
				
					
		8'd13:	begin//����һ����ַ������֮��ȴ�?24��ʱ������
				if(cnt==22'd0)
						begin
						state<=8'd14;
						end
					else
						begin
						cnt	<=cnt-1'b1;
						cs_b	<=1'b1;
						sclk	<=1'b1;
						sdout	<=1'b1;
						state	<=8'd13;
						end			
				end				
		8'd14:	begin      //��������Ƿ���꣬û����Ļ�����״�?8����
				if(m==Rd_n)//��һ����ַ���ݵĶ��������������ɡ�
						begin
						state<=8'd15;
						m<=8'd1;
						cnt<=22'd23;
						end
				else
						begin
						m		<=m+1;
						state	<=8'd8;
						cnt		<=22'd23;
						end
				end							
		8'd15:	begin
					// if ((RdData1==8'h00)&&(RdData3==8'h18))begin//&&(RdData2==8'h07)
					// 	if(image_en &&(RdData2==8'h04))	begin
					// 		state <= 4;
					// 		Tri_en  	<=1'b1;
					// 	end
					// 	else if(image_en &&(RdData2==8'h00))	begin
					// 		state <= 'd15;
					// 		Tri_en  	<=1'b1;
					// 		CfgDone 	<=1'b1;
					// 	end
					// 	else
					// 	begin
					// 		state		<=8'd15;
					// 		end
					// 	end
					// else
					// 	begin
					// 		CfgDone <=1'b0;
					// 		state	<=8'd16;
					// 	end
					// if ((RdData1==8'h00)&&(RdData3==8'h18))begin//&&(RdData2==8'h07)
					// 	if(image_en &&(RdData2==8'h04))	begin
					// 		state <= 4;
					// 		Tri_en  	<=1'b1;
					// 	end
					// 	else if(image_en &&(RdData2==8'h00))	begin
					// 		state <= 'd15;
					// 		Tri_en  	<=1'b1;
					// 		CfgDone 	<=1'b1;
					// 	end
					// 	else
					state		<=8'd15;

					// else
					// 	begin
					// 		CfgDone <=1'b0;
					// 		state	<=8'd16;
					// 	end
				end	
		default:	state	<=8'd16;			
	endcase
endmodule

				