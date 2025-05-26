# installator
script d'installation de logiciel sur debian 12

GLPI, Zabbix et wordpress s'installent avec apache et peuvent cohabiter sur la meme machine.
Xivo s'install avec docker et prend aussi le port 80, vous ne pourrez donc pas le faire tourner avec les autres


<p align="center">
  <img src="https://private-user-images.githubusercontent.com/187048139/447597064-53eda9f4-eed2-4436-8930-9b93d6e7a64b.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NDgyNjg1NDUsIm5iZiI6MTc0ODI2ODI0NSwicGF0aCI6Ii8xODcwNDgxMzkvNDQ3NTk3MDY0LTUzZWRhOWY0LWVlZDItNDQzNi04OTMwLTliOTNkNmU3YTY0Yi5wbmc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjUwNTI2JTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI1MDUyNlQxNDA0MDVaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT0wNGFhYmRhNzRiY2NlMzcyNDAyYzQ4NzMzNzliZTM2NGY5NzUxYTY1ZDU1OTI3ZDBlY2Y3YTRhOTA5NjE3NjY1JlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCJ9.r3RW3l9HBXP1MGDKjVa0HOOFk-vx2JrrKXcSQm-Idok" alt="Description de l'image" width="600"/>
</p>




Pré-requis :
```
apt install -y sudo git
```

Utilisation :
```
git clone  https://github.com/edo-ops/installator 
cd installator
sudo chmod +x installator.sh
sudo ./installator.sh
```
