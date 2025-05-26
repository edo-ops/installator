# installator
script d'installation de GLPI, Zabbix et Xivo sur debian 12

GLPI et Zabbix s'install avec apache et peuvent se mettre sur la meme machine
Xivo s'install avec docker et prend aussi le port 80, vous ne pourrez donc pas avoir les 3 logiciels tournant sur la meme machine 



<p align="center">
  <img src="https://private-user-images.githubusercontent.com/187048139/447594254-7e3a869a-3d52-4e4f-8e31-4d46f1a3d7db.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NDgyNjgwNTUsIm5iZiI6MTc0ODI2Nzc1NSwicGF0aCI6Ii8xODcwNDgxMzkvNDQ3NTk0MjU0LTdlM2E4NjlhLTNkNTItNGU0Zi04ZTMxLTRkNDZmMWEzZDdkYi5wbmc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjUwNTI2JTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI1MDUyNlQxMzU1NTVaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT1lOWMzODk4NGIwMjAyZTZjMTdiMjI5NmM4ODUxY2EyMWE4NjAwYmE3Nzc1NjhjNjg5YWFkZWU4MjdkMjlmYTJkJlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCJ9.9qcW_N0TkC28K7sv-V-sRsNsMMcCA-wixf_SmAmWNm0" alt="Description de l'image" width="600"/>
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
