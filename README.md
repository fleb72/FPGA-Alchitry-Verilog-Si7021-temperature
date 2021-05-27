# FPGA-Alchitry-temperature sensor si7021

## Verilog driver for the si7021 temperature sensor

![Alchitry Au + Adafruit Si7021 module](images/20210526_185742.jpg)

### Matériels

 - carte FPGA [Alchitry Au](https://alchitry.com/products/alchitry-au-fpga-development-board) ;
 - module [Adafruit Si7021](https://www.adafruit.com/product/3251) (système [Qwiic Connect](https://www.sparkfun.com/qwiic) de Sparkfun) ;
 - [câbles Qwiic](https://www.sparkfun.com/categories/tags/qwiic-cables) de Sparkfun ;
 - facultatif : pour visualiser les trames I2C, analyseur logique compatible *Saleae* à bas coût (24 MHz, 8 canaux).
 
### EDI Alchitry Labs
 
 - [EDI Alchitry Labs v1.2.6](https://alchitry.com/pages/alchitry-labs) ;
  
![Fichiers du projet](images/AlchitryLabs.PNG)
 - Rajouter les composants *UART TX* (affichage des résultats dans un terminal série) et *I2C Controller* (communication I2C avec Si7021) ;
 - Rajouter le fichier des contraintes *io.acf* pour la localisation des broches SDA et SCL (voir dans le dossier *constraint*)
  



