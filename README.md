# installator
script d'installation de GLPI, Zabbix et Xivo sur debian 12

GLPI et Zabbix s'install avec apache et peuvent se mettre sur la meme machine
Xivo s'install avec docker et prend aussi le port 80, vous ne pourrez donc pas avoir les 3 logiciels tournant sur la meme machine 

![image](https://github.com/user-attachments/assets/bf5d196c-f231-4655-951f-cb6fae11242b)

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
