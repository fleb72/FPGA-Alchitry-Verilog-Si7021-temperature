module serialTemperatureDisplay(clk, rst, usb_tx, temperature, enable);
    input clk;              // 100MHz clock
    input rst;              // reset
    output usb_tx;          // USB->Serial output
    input wire [31:0] temperature;
    input enable;          
    
    wire busy_tx;
    reg [7:0] data_tx;
    reg new_data_tx;
    reg block_tx;
    integer temperature_abs;
    
    localparam LENGTH = 16, STR = "Temp = xxx.x C\r\n"; // gabarit de la chaine de caract�res � envoyer et sa taille
    localparam SIGN = 9, HUNDREDS = 8, TENS = 7, UNITS = 5; // position du signe, des chiffres centaines/dizaines/unit�d
    
    reg [LENGTH*8:1] s;
    reg[7:0] t1, t2, t3;
    
    reg [7:0] counter, counter_next; 
    
    uart_tx  #(.BAUD(115200), .CLK_FREQ(100000000)) tx (
      .clk(clk),
      .rst(rst),
      .tx(usb_tx),
      .busy(busy_tx),
      .data(data_tx),
      .new_data(new_data_tx),
      .block(block_tx)
    );
          
    /* ------ Gestion de la machine � �tats finis ------------------------------------ */
    reg state, state_next;
    
    localparam state_1 = 1'd0,
               state_2 = 1'd1;

    initial begin
      counter <= LENGTH;
      state <= state_1;
    end 
                                                  
    always @(posedge clk or posedge rst) begin
      if (rst) begin
        state <= state_1;
      end else begin 
        state <= state_next;  // passage � l'�tat suivant, synchronis� avec l'horloge
      end
    end 
    
    always @(posedge clk) begin
      counter <= counter_next;
    end
    
    always @(posedge enable) begin // pr�paration de la cha�ne de caract�res � transmettre
      s = STR;
      
      if (temperature[31]) begin // si temp�rature n�gative (bit de poid fort = 1)
        s[SIGN*8-:8] =  "-";
      end else begin
        s[SIGN*8-:8] =  "+";
      end
      
      temperature_abs = (temperature[31]) ? ~temperature + 1 : temperature; // valeur absolue si n�gatif
      
      t1 =  temperature_abs / 100;          // chiffre des centaines
      t2 = (temperature_abs % 100) / 10;    // chiffre des dizaines
      t3 = ((temperature_abs % 100) % 10);  // chiffre des unit�s
      s[HUNDREDS*8-:8] = "0" + t1;
      s[TENS*8-:8]     = "0" + t2;
      s[UNITS*8-:8]    = "0" + t3;
    end
        
    always @(*) begin // transmission UART Tx

      // valeurs par d�faut
      state_next = state;
      
      new_data_tx = 0;
      block_tx = 0;
      data_tx = "";

      counter_next <= counter;
         
      case (state)
                  
        state_1 : begin
          counter_next <= LENGTH;
          if (enable) begin  // si nouvelle donn�e de temp�rature disponible
            state_next = state_2;
          end
        end   
    
        state_2 : begin
          if (!busy_tx) begin // si le port UART Tx est libre               
            new_data_tx = 1;             // signaler une nouvelle donn�e
            data_tx = s[(counter*8)-:8]; // caract�re � transmettre
            counter_next <= counter - 1; // aller au caract�re suivant
            
            if (counter  == 1) begin  // si tous les caract�res ont �t� transmis            
              state_next = state_1;             
            end
          end
        end
        
      endcase 
        
    end
    
endmodule
