#!/bin/bash

# Backup MySQL/MariaDB GUI - Multi-langue FR/EN
# Projet BTS SIO SLAM - https://github.com/djael-ml/BashServerBackup

# Vérifier Zenity
sudo apt install zenity
if ! command -v zenity &> /dev/null; then
    zenity --error --text="Installez Zenity : sudo apt install zenity" --title="Erreur"
    exit 1
fi

# Choix langue
LANGUE=$(zenity --list --radiolist \
    --title="Choisir la langue / Choose language" \
    --text="Sélectionnez votre langue :" \
    --column="Sélection" --column="Langue" \
    TRUE "Français" \
    FALSE "English" \
    --width=300 --height=150)

if [ $? -ne 0 ]; then exit 1; fi

# Messages selon langue
if [ "$LANGUE" = "Français" ]; then
    TITLE="🛡️ Backup MySQL GUI"
    TEXT_DB="Nom de la base de données :"
    TEXT_USER="Utilisateur MySQL :"
    TEXT_PASS="Mot de passe MySQL :"
    TEXT_REMOTE_USER="Utilisateur distant (SSH) :"
    TEXT_REMOTE_IP="IP distante (VM2/VM3) :"
    TEXT_REMOTE_DIR="Dossier distant :"
    TEXT_SUCCESS="✅ Backup terminé ! Fichier :"
    TEXT_ERROR="❌ Erreur :"
    MSG_FIN="Sauvegarde terminée et envoyée ! 📦"
else
    TITLE="🛡️ MySQL Backup GUI"
    TEXT_DB="Database name :"
    TEXT_USER="MySQL user :"
    TEXT_PASS="MySQL password :"
    TEXT_REMOTE_USER="Remote SSH user :"
    TEXT_REMOTE_IP="Remote IP (VM2/VM3) :"
    TEXT_REMOTE_DIR="Remote directory :"
    TEXT_SUCCESS="✅ Backup done ! File :"
    TEXT_ERROR="❌ Error :"
    MSG_FIN="Backup completed and sent ! 📦"
fi

# Saisie infos avec mot de passe masqué
DB_NAME=$(zenity --entry --title="$TITLE" --text="$TEXT_DB" --entry-text="projet_db")
MYSQL_USER=$(zenity --entry --title="$TITLE" --text="$TEXT_USER" --entry-text="admin_user")
MYSQL_PASS=$(zenity --password --title="$TITLE" --text="$TEXT_PASS")
REMOTE_USER=$(zenity --entry --title="$TITLE" --text="$TEXT_REMOTE_USER" --entry-text="utilisateur")
REMOTE_IP=$(zenity --entry --title="$TITLE" --text="$TEXT_REMOTE_IP" --entry-text="IP_DE_LA_VM2")
REMOTE_DIR=$(zenity --entry --title="$TITLE" --text="$TEXT_REMOTE_DIR" --entry-text="/home/utilisateur/backups")

# Vérif IP valide (simple)
if ! [[ $REMOTE_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    zenity --error --text="IP invalide !" --title="$TEXT_ERROR"
    exit 1
fi

# Variables
DATE=$(date +%Y%m%d_%H%M)
FILENAME="dump_${DATE}.sql"
DEST_DIR="/srv/backups"
mkdir -p "$DEST_DIR"

BACKUP_FILE="${DEST_DIR}/${FILENAME}"

# Test connexion MySQL
if ! mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASS" "$DB_NAME" --no-data -h localhost >/dev/null 2>&1; then
    zenity --error --text="❌ Connexion MySQL échouée !" --title="$TEXT_ERROR"
    exit 1
fi

# Faire dump (progress bar)
(
    echo "# Dump en cours... ⏳"
    sleep 1
    mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASS" "$DB_NAME" > "$BACKUP_FILE"
    if [ $? -eq 0 ]; then
        echo "100"
    else
        echo "Erreur dump !"
        exit 1
    fi
) | zenity --progress --title="$TITLE" --text="Dump MySQL..." --percentage=0 --auto-close --width=400

if [ $? -ne 0 ]; then
    zenity --error --text="❌ Échec dump !" --title="$TEXT_ERROR"
    exit 1
fi

# Test SSH + SCP
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$REMOTE_USER@$REMOTE_IP" "exit" 2>/dev/null; then
    zenity --error --text="❌ SSH échoué ! Configurez clé SSH (ssh-copy-id)." --title="$TEXT_ERROR"
    exit 1
fi

# Envoi SCP (progress)
(
    echo "# Envoi vers $REMOTE_IP... 🚀"
    scp "$BACKUP_FILE" "$REMOTE_USER@$REMOTE_IP:$REMOTE_DIR/"
    if [ $? -eq 0 ]; then
        echo "100"
    fi
) | zenity --progress --title="$TITLE" --text="Envoi SCP..." --percentage=0 --auto-close --width=400

# Succès
zenity --info --title="$TITLE" --text="$TEXT_SUCCESS\n$BACKUP_FILE\n\n$MSG_FIN" --width=400

echo "Backup OK: $BACKUP_FILE envoyé à $REMOTE_USER@$REMOTE_IP" | tee -a /var/log/backup.log