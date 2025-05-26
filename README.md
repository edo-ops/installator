# installator
script d'installation de logiciel sur debian 12

GLPI, Zabbix et wordpress s'installent avec apache et peuvent cohabiter sur la meme machine.

Xivo s'installe avec docker et prend le port 80, vous ne pourrez donc pas le faire tourner avec les autres.




<p align="center" style="margin-top: 200px; margin-bottom: 100px;">
  <img src="https://github.com/user-attachments/assets/cc23e731-f399-4c8c-81a9-2cecd412f287" alt="Description de l'image" width="600"/>
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
