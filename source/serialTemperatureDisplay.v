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
    
    localparam LENGTH = 16, STR = "Temp = xxx.x C\r\n"; // gabarit de la chaine de caractères à envoyer et sa taille
    localparam SIGN = 9, HUNDREDS = 8, TENS = 7, UNITS = 5; // position du signe, des chiffres centaines/dizaines/unitéd
    
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
          
    /* ------ Gestion de la machine à états finis ------------------------------------ */
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
        state <= state_next;  // passage à l'état suivant, synchronisé avec l'horloge
      end
    end 
    
    always @(posedge clk) begin
      counter <= counter_next;
    end
    
    always @(posedge enable) begin // préparation de la chaîne de caractères à transmettre
      s = STR;
      
      if (temperature[31]) begin // si température négative (bit de poid fort = 1)
        s[SIGN*8-:8] =  "-";
      end else begin
        s[SIGN*8-:8] =  "+";
      end
      
      temperature_abs = (temperature[31]) ? ~temperature + 1 : temperature; // valeur absolue si négatif
      
      t1 =  temperature_abs / 100;          // chiffre des centaines
      t2 = (temperature_abs % 100) / 10;    // chiffre des dizaines
      t3 = ((temperature_abs % 100) % 10);  // chiffre des unités
      s[HUNDREDS*8-:8] = "0" + t1;
      s[TENS*8-:8]     = "0" + t2;
      s[UNITS*8-:8]    = "0" + t3;
    end
        
    always @(*) begin // transmission UART Tx

      // valeurs par défaut
      state_next = state;
      
      new_data_tx = 0;
      block_tx = 0;
      data_tx = "";

      counter_next <= counter;
         
      case (state)
                  
        state_1 : begin
          counter_next <= LENGTH;
          if (enable) begin  // si nouvelle donnée de température disponible
            state_next = state_2;
          end
        end   
    
        state_2 : begin
          if (!busy_tx) begin // si le port UART Tx est libre               
            new_data_tx = 1;             // signaler une nouvelle donnée
            data_tx = s[(counter*8)-:8]; // caractère à transmettre
            counter_next <= counter - 1; // aller au caractère suivant
            
            if (counter  == 1) begin  // si tous les caractères ont été transmis            
              state_next = state_1;             
            end
          end
        end
        
      endcase 
        
    end
    
endmodule
