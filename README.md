# installator
script d'installation de logiciel sur debian 12

GLPI, Zabbix et wordpress s'installent avec apache et peuvent cohabiter sur la meme machine.

Xivo s'installe avec docker et prend le port 80, vous ne pourrez donc pas le faire tourner avec les autres.




<p align="center" style="margin-top: 200px; margin-bottom: 100px;">
  <img src="https://private-user-images.githubusercontent.com/187048139/447648400-30340e1b-c8e0-4192-9e12-e53c4b941868.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NDgyODAzMTgsIm5iZiI6MTc0ODI4MDAxOCwicGF0aCI6Ii8xODcwNDgxMzkvNDQ3NjQ4NDAwLTMwMzQwZTFiLWM4ZTAtNDE5Mi05ZTEyLWU1M2M0Yjk0MTg2OC5wbmc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjUwNTI2JTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI1MDUyNlQxNzIwMThaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT1kOGEwM2ZlN2EzNjQ5MjJiZjliY2I4MzI1NjY3NWQzMTUyMjRmOWUzMTQxNGE5ZDg0MWE3OGNiN2I2MWExYjI3JlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCJ9.xKbWUlMkDKBTnBpkRDoyE8qBKSmUMUney_dYHEjEjRk" alt="Description de l'image" width="600"/>
</p>





Pré-requis :
```
apt install -y sudo git
```

Utilisation :
```
git clone  https://github.com/edo-ops/installator 
cd installator
sudo chmod +x *.sh
./installator.sh
```
