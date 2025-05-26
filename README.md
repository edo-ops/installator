# installator
script d'installation de GLPI, Zabbix et Xivo sur debian 12

GLPI et Zabbix s'install avec apache et peuvent se mettre sur la meme machine
Xivo s'install avec docker et prend aussi le port 80, vous ne pourrez donc pas avoir les 3 logiciels tournant sur la meme machine 


<p align="center">
  <img width="460" height="300" src="https://github.com/user-attachments/assets/d7e82889-9235-4504-8a52-8f915ec7827a/460/300">
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
