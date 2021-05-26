module au_top (
    input clk,              // horloge 100 MHz
    input rst_n,            // bouton Reset, actif � l'�tat bas
    output [7:0] led,       // jeu de LED x 8, non utilis�
    input  usb_rx,          // liaison s�rie USB : Rx, non utilis�          
    output usb_tx,          // liaison s�rie USB : Tx
    output scl,             // Serial Clock I2C, g�n�r�e par le ma�tre
    inout sda               // Serial Data I2C, /!\ SDA, port bidirectionnel
  );

    assign led = 8'h00;          // LED x 8 �teintes    
                                    
    wire rst;                          // signal reset synchrone, rst=1 si appui sur bouton Reset
    reset_conditioner rst_cond_inst (  // Conditionnement & synchronisation du signal Reset
      .clk(clk),
      .in(!rst_n),
      .out(rst)
    );
    
    /* ------- Affichage temp�rature en �C via liaison UART Tx 115 200 bauds 8N1-------------- */         
    integer temperature_32bits;   // Pour calcul de temp�rature sur 32 bits                                                   
    reg temperature_enable;       // =1 quand la transaction I2C est compl�te
                                          
    serialTemperatureDisplay std (   // instance affichage via liaison s�rie UART
      .clk(clk),
      .rst(rst),
      .temperature(temperature_32bits),
      .usb_tx(usb_tx),
      .enable(temperature_enable)
    );
    /* -------------------------------------------------------------------------------------------- */
               
    /* ---- Instantiation & connexion du contr�leur I2C ----------------------------------*/  
    reg i2c_start;            // signal Start (S) ou Start Repeated (Sr)
    reg i2c_stop;             // signal Stop  (P)
    wire i2c_busy;            // =1 si le bus I2C est occup�
    wire i2c_out_valid;       // =1 quand la donn�e retourn�e (1 octet) en sortie est valide et disponible
    reg [7:0] i2c_data_in;    // octet � transmettre (ma�tre vers esclave)
    wire [7:0] i2c_data_out;  // octet retourn� (esclave vers ma�tre)
    reg i2c_write;            // =1, demande d'�criture par le ma�tre sur le bus
    reg i2c_read;             // =1, demande de lecture par le ma�tre sur le bus
    reg i2c_ack_read;         // =1 si le ma�tre doit acquitter
    wire i2c_ack_write_n, i2c_ack_write;  // sortie ack_write du contr�leur=0 si l'esclave acquitte, /!\ erreur dans la doc.
    
    assign i2c_ack_write = !i2c_ack_write_n;
       
    i2c_controller #(.CLK_DIV(9)) Si7021_controller ( // fr�quence clk = 100_000_000 / 2^9 = 195,3 kHz
      .clk(clk),
      .rst(rst),
      .scl(scl),
      .sda(sda),
      .start(i2c_start),
      .stop(i2c_stop),
      .busy(i2c_busy),
      .data_in(i2c_data_in),
      .data_out(i2c_data_out),
      .write(i2c_write),
      .read(i2c_read),
      .ack_write(i2c_ack_write_n),
      .ack_read(i2c_ack_read),
      .out_valid(i2c_out_valid)
    );   
    
    localparam [7:0] I2C_ADR_Si7021 = 8'h40, // adresse du composant I2C Si7021 = 0x40
                     I2C_ADR_Si7021_Read  = (I2C_ADR_Si7021 << 1) + 1, 
                     I2C_ADR_Si7021_Write = (I2C_ADR_Si7021 << 1);
    /* ------------------------------------------------------------------------------- */
          
    /* ------ Gestion de la machine � �tats finis ------------------------------------ */
    reg [3:0] I2C_State, I2C_State_Next;
    
    localparam state_I2C_RESET_START   = 4'd0,
               state_I2C_RESET_ADRW    = 4'd1,
               state_I2C_RESET_CMD     = 4'd2,
               state_I2C_RESET_STOP    = 4'd3,    
               state_I2C_START         = 4'd4,
               state_I2C_ADRW          = 4'd5,
               state_I2C_START_RE      = 4'd6,        
               state_I2C_ADRR          = 4'd7,
               state_I2C_MEASURE_CMD   = 4'd8,
               state_I2C_READ_MSB      = 4'd9,
               state_I2C_READ_LSB      = 4'd10,
               state_I2C_READ_CHKSUM   = 4'd11,
               state_I2C_STOP          = 4'd12; 
               
    always @(posedge clk or posedge rst) begin
      if (rst) begin
        I2C_State <= state_I2C_RESET_START;
      end else begin
        if (!i2c_busy) begin            // si pas d'action en cours sur le bus I2C,
          I2C_State <= I2C_State_Next;  // passage � l'�tat suivant, synchronis� avec l'horloge
        end
      end
    end 
    /* ---------------------------------------------------------------------------------------- */
    
    reg [23:0] raw_data;    // registre avec donn�es brutes retourn�es par le capteur : | MSB | LSB | CheckSum |   
    reg [30:0] delay;       // valeur chronom�tre pour temporisation
    

    always @(posedge i2c_out_valid) begin // si 1 octet est retourn� par le capteur 
      raw_data[7:0] <= i2c_data_out;      // on le d�cale dans le registre raw_data
      raw_data[23:8] <= raw_data[15:0];
    end         
      
    always @(posedge clk) begin
      if (temperature_enable) begin
        temperature_32bits = ((raw_data[23:8] * 1757) >> 16) - 469; // calcul de T(�C)x10, voir datasheet Si7021
        // Au besoin, CheckSum est dans raw_data[7:0]
      end 
    end           
                                                               
    always @(posedge clk) begin
      if (I2C_State != I2C_State_Next) begin // remise � z�ro du chrono � chaque changement d'�tat
        delay <= 0;
      end else begin
        delay <= delay + 1;
      end                                                                                    
    end
    
    /*----------- G�n�ration de la trame I2C ----------------------------------------------- */                                                                                                                                                                                                                                      
    always @(I2C_State, i2c_ack_write, delay) begin
      I2C_State_Next = I2C_State;
      
      // valeurs par d�faut 
      i2c_stop = 0;
      i2c_write = 0;
      i2c_read = 0;
      i2c_start = 0;
      i2c_data_in = 0;
      i2c_ack_read = 0;
      temperature_enable = 0;
          
      case (I2C_State)
                  
        state_I2C_RESET_START : begin
          if (delay > 1_000_000) begin // attendre 10ms avant de d�marrer
            i2c_start = 1;
            I2C_State_Next = state_I2C_RESET_ADRW;
          end 
        end       
  
        state_I2C_RESET_ADRW : begin
            i2c_write = 1;
            i2c_data_in = I2C_ADR_Si7021_Write;
            I2C_State_Next = state_I2C_RESET_CMD;                    
        end
          
        state_I2C_RESET_CMD : begin
            i2c_write = 1;
            i2c_data_in = 8'hFE;  // commande Reset, voir datasheet Si7021
            I2C_State_Next = state_I2C_RESET_STOP;  
        end
          
        state_I2C_RESET_STOP : begin
            i2c_stop = 1;
            I2C_State_Next = state_I2C_START;
        end 
          
        state_I2C_START : begin
          if (delay > 100_000_000) begin // 1 mesure par seconde
            i2c_start = 1;
            I2C_State_Next = state_I2C_ADRW;
          end                 
        end
          
        state_I2C_ADRW : begin
            i2c_write = 1;
            i2c_data_in = I2C_ADR_Si7021_Write;  // Slave Address (0x40) + Write
            I2C_State_Next = state_I2C_MEASURE_CMD;             
        end  
        
        state_I2C_MEASURE_CMD : begin
            /* if (i2c_ack_write) begin... // Si on veut tester que le module acquitte bien... */
            i2c_write = 1;
            i2c_data_in = 8'hF3; // Command 0xF3, Temperature, No Hold Master Mode. Voir datasheet Si7021
            I2C_State_Next = state_I2C_START_RE;
        end
          
        state_I2C_START_RE : begin
            /* if (i2c_ack_write) begin... // Si on veut tester que le module acquitte bien... */
            if (delay > 200_000) begin // relancer apr�s 2 ms             
              i2c_start = 1; // Start Repeated
              I2C_State_Next = state_I2C_ADRR;
            end
        end
                    
        state_I2C_ADRR : begin
            i2c_write = 1;
            i2c_data_in = I2C_ADR_Si7021_Read; // Slave Address (0x40) + Read
            I2C_State_Next = state_I2C_READ_MSB;
        end 
        
        state_I2C_READ_MSB : begin
            if (!i2c_ack_write) begin // Si NAK, la conversion n'est pas termin�e
              I2C_State_Next = state_I2C_START_RE;
            end else begin  // Sinon si ACK, la conversion est termin�e
              i2c_read = 1; // Lecture Temperature MSB
              i2c_ack_read = 1;
              I2C_State_Next = state_I2C_READ_LSB;
            end
        end
                 
        state_I2C_READ_LSB : begin
            i2c_read = 1; // Lecture Temperature LSB
            i2c_ack_read = 1;
            I2C_State_Next = state_I2C_READ_CHKSUM;      
        end
          
        state_I2C_READ_CHKSUM : begin
            i2c_read = 1; // Lecture Temperature CheckSum
            I2C_State_Next = state_I2C_STOP; 
        end
          
        state_I2C_STOP : begin
            temperature_enable = 1; // transaction compl�te
            i2c_stop = 1;
            I2C_State_Next = state_I2C_START;
        end
          
      endcase
 
    end 
           
endmodule