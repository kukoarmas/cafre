# CAFRE

CAINE Advanced Forensic Recordable Environment

## Descripción

CAFRE es un conjunto de herramientas para preparar un entorno de adquisición forense autocontenido en el que en el mismo medio de almacenamiento donde vamos a almacenar las evidencias obtenidas, tenemos todo el entorno de adquisicion

La ventaja de este enfoque es que el propio entorno completo utilizado para la adquisición de evidencias queda almacenado, junto con todos los logs de acciones realizadas, en el propio dispositivo donde se han volcado las evidencias adquiridas, por lo que el entorno es totalmente auditable como una evidencia más.

## Esquema del entorno CAFRE

Para que sea auditable, no solo el entorno base utilizado, sino tambien las acciones ejecutadas durante el proceso de adquisición de evidencias, utilizamos una funcionalidad avanzada de la distribucuión de Linux CAINE, que consiste en disponer de una "capa" de lectura/esctritura sobre la base de solo lectura del entorno Live de CAINE.
De esta forma, tenemos una capa de solo lectura formada por el contenido de la distribución CAINE, cuya integridad es facilmente verificable mediante los hashes MD5 de la distrubución oficina, y otra capa de lectura/escritura donde quedan almacenados los logs de la distribución, el histórico de comandos ejecutados, etc. Tambien podemos extender la auditabilidad del proceso registrando explicitamente las operaciones realizadas (mediante grabado de la pantalla, etc)

El entorno CAFRE esta, por tanto, formado por 3 particiones principales:

  * Entorno base CAINE: Tipicamente en la primera partición. De tamaño 4GB y con sistema de ficheros vfat con etiqueta "CASPER". Contiene el entorno completo de CAINE y se monta en solo lectura, por lo que es fácilmente auditable.
  * Entorno de lectura/escritura: Típicamente en la segunda partición. De tamaño 4GB y con sistema de ficheros ext2 con etiqueta casper-rw. Contiene la capa de lectura/escritura que se monta sobre la anterior. En esta partición quedan almacenados todos los datos que se escriban y/o modifiquen durante la ejecución del entorno Live utilizado para la adquisición de evidencias. Es MUY importante comenzar el proceso de adquisición de evidencias con esta partición totalmente vacía, para evitar contaminarla con acciones no pertenecientes al proceso de extración.
  * Partición para las evidencias adquiridas: Típicamente en la tercera partición. Utiliza todo el espacio disponible, formateada con vfat y etiqueta "EVIDENCE". Se utiliza desde CAINE para volcar las evidencias a esa partición.

La razón de utilización de etiquetas con nombre "casper" es que asi se llama el entorno utilizado por CAINE para el sistema de arranque en modo Live.

## Preparación manual

El proceso de preparación esta planteado para poder ser ejecutado desde un entorno LIVE de CAINE

El proceso de preparación del entorno es el siguiente

  * Conectar el dispositivo que se usará para el proceso de adquisición de evidencias. Típicamente será un disco duro externo USB de capacidad suficiente para almacenar las evidencias que se pretenden extraer. Hay que tener en cuenta, que el entorno CAFRE utilizará aproximadamente 8GB de almacenamiento (4GB para la base CAINE y 8GB para el "overlay" de lectura/escritura. En los siguientes ejemplos se asume que el dispositivo conectado es "/dev/sdb"

  * Crear las 3 particiones

```bash
sfdisk /dev/sdb <<__EOF__
,4G,c,*
,4G
,,c
__EOF__
```

  * Formatear las particiones

```bash
mkfs.vfat -n CASPER /dev/sdb1
mkfs.ext2 -L casper-rw /dev/sdb2
mkfs.vfat -n EVIDENCE /dev/sdb3
```

  * Montar la primera particion

```bash
mount /dev/sdb1 /mnt
```

  * Copiar el entorno completo CAINE (asumiendo que esta montado en /cdrom)

```bash
rsync -av /cdrom/ /mnt
```

  * Escribir MBR de syslinux en /dev/sdb

```bash
dd if=/usr/lib/syslinux/mbr/mbr.bin of=/dev/sdb
```

  * Instalar syslinux

```bash
syslinux -s /dev/sdb1
```

  * El paso anterior nos añade 2 nuevos ficheros al entorno readonly de CAINE:

```bash
root@caine:/mnt# md5sum ldlinux.*
bf4d919865a04949f6be15886e8259b9  ldlinux.c32
b000dea8c16024f7aad82e14cacd3fca  ldlinux.sys
```

  * Copiar la carpeta isolinux a syslinux

```bash
cp -av /mnt/isolinux /mnt/syslinux
```

  * Renombrar el fichero /mnt/syslinux/isolinux.cfg a /mnt/syslinux/syslinux.cfg

```bash
mv /mnt/syslinux/isolinux.cfg /mnt/syslinux/syslinux.cfg
```

  * Añadir la siguiente entrada a /mnt/syslinux/syslinux.cfg

```
label live-persistent
  menu label START CAINE LIVE PERSISTENT
  kernel /casper/vmlinuz
  append file=/cdrom/preseed/custom.seed boot=casper boot=casper initrd=/casper/initrd.gz fsck.mode=skip persistent live-media=/dev/disk/by-label/CASPER
```

  * Y añadimos la opcion "nopersistent" a la primera entrada que ya existia

```
label live
  menu label START CAINE LIVE
  kernel /casper/vmlinuz
  append file=/cdrom/preseed/custom.seed boot=casper boot=casper initrd=/casper/initrd.gz fsck.mode=skip quiet splash nopersistent
```


## Usage

Basic usage of the cafre.sh script

```
cafre.sh [-h] | command options

Uso:
  -h              : Shows this help message
  -d              : Debug. Show debug messages
  -n              : Do nothing. Just show what should be done

Valid commands:

   - info: Show basic info about CAFRE environment
       - options: NONE
       - examples: 
           cafre info
   - setup: Setup the given device as a CAFRE boot device
       - options: DEVICE The device we want to use. ALL INFORMATION IN THIS DEVICE WILL BE DELETED
       - examples: 
           cafre setup /dev/sdb
   - hash_dir: Generate sha256 hashes for all files in the given dir (recursively)
       - options: DIRECTORY The directory containing the files we want to create hashes for
       - examples: 
           cafre hashdir /evidences
   - timestamp: Generate an external signature and timestamp for the given file (with FreeTSA)
       - options: FILE The file we want to timestamp
       - examples: 
           cafre timestamp sha256sum.txt
   - verify_timestamp: Verifies a given timestamp to make sure it's correct
       - options: FILE The file we want to check the timestamp for
       - examples: 
           cafre verify_timestamp sha256sum.txt
   - wipe_rw: Wipe (empty) the read/write overlay partition
       - options: NONE
       - examples: 
           cafre wiper_rw
   - protect_rw: Protect the read/write overlay partition (changing it's label to casper-rw-protec)
       - options: NONE
       - examples: 
           cafre protect_rw
   - unprotect_rw: Unprotect the read/write overlay partition (changing it's label back to casper-rw)
       - options: NONE
       - examples: 
           cafre unprotect_rw
```
