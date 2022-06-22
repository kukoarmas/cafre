# CAFRE

CAINE Advanced Forensic Recordable Environment

## The CAFRE forensic environment

CAFRE is a CAINE based forensic acquisition environment aimed to minimize the chances that the acquired evidences are rejected in court due to incorrect handling of the evidences or not trusting the forensic environment used to acquiring them.

The main features of the CAFRE environment are:

  * It is based in the excellent and widely used CAINE Linux forensic distribution. Also, this makes it trivial to check the integrity of the system, it only requires to check the binary hashes against the ones published by the CAINE project.
  * The forensic environment is installed in the same external drive where the acquired evidences will be stored. This way, only this drive is used during the acquisition process.
  * CAFRE uses an overlay persistent partition to record the activity run in the environment during the acquisition process. This way, the same device will contain forensic artifacts that can be used to trace the actions done during the acquisition to make sure the original evidences where not contaminated.
  * It contains tools to generate SHA256 hashes of the acquired evidences, and get a signed timestamp of the hashes file. This way, any tampering with the evidences can be detected checking the hashes file, and any tampering with the hashes file can be detected with the digital signature. The timestamp also proves the exact moment in time when the acquisition process was completed.
  * The forensic environment will be kept with the acquired evidences (in the same drive). So, if anyone questions the integrity of the used environment, or the actions executed, it can be subject to a forensic examination, just as the acquired evidences.

Partitions in a device with the CAFRE environment:

  * Partition 1: Boot partition. Its a base CAINE live partition that will be mounted readonly. This way this partition never changes and checking it's integrity is trivial: just check the hashes.
  * Partition 2: Overlay persistent partition. Will be mounted over the first partition to save all changes done to the system. All actions done during the acquisition process will create artifacts in this partition (logs, created files, bash_history, etc). It is also useful to get screenshots and screen recordings during the process, all these screenshots and recordings will be stored in this partition.
  * Partition 3: The EVIDENCE partition. It's where the acquired evidences will be stored. It will use all available disk space.

Since the default boot option does not use the persistent partition, **the device can be used to run forensic examination of itself**. Just boot with the default non persistent option, check the integrity of the readonly system, mount the persistent partition readonly, and analyze the artifacts.

## The cafre tool

The cafre tool contained in this repository, is a bash command line tool to simplify some of the actions needed to manage a CAFRE forensic environment.

It's written in bash because it's a very simple tool, and, since it's a forensic tool, it has to be easily auditable: just read the code.

### Available commands

#### CAFRE environment setup

In order to do the forensic acquisition, you normally start the target computer with the forensic environment live system.

This command installs de CAFRE forensic environment in an external drive. This drive can then be used to boot the target computer and acquire the evidences to the third partition in the same drive.

When choosing the disk, make sure it's big enough to store the evidences you need to acquire, and the full forensic environment. 
The CAFRE forensic environment normally uses 4GB for the boot partition and 4GB for the persistent overlay partition (8GB in total)

To run setup on a device:

```bash
./cafre setup DEVICE
```

This will:

  * Create, format and label the three partitions
  * Copy the running CAINE to the first partition and setup boot
  * Add a second boot option for persistent boot (to use only during the acquisition process)
  * Copy the cafre tool to the boot partition
  * Generate SHA256 hashes for all files in the boot partition
  * Generates a signed timestamp for the hashes file, using FreeTSA provider

#### Info command

Just shows some information about the running environment

```bash
caine@caine:/cdrom/cafre$ ./cafre info
CAFRE Forensic environment version 0.1.1
Running on CAINE 12

Persistence partition is UNPROTECTED

Running in NON PERSISTENT mode
```

#### Persistent overlay management

These are some commands for handling the persistent overlay partition

##### Protect the overlay partition

The default behaviour for a CAINE live environment is mounting any detected "casper-rw" partition under /var/log, even if not using the "persistent" boot option. To avoid this behaviour, the option **nopersistent** must be used
So, if a plain CAINE live environment is booted with a connected device with the CAFRE setup, it will wipe all information in the overlay partition. If it is done after doing the forensic acquisition, all artifacts created during the acquire process will be lost (not the acquired evidences, but the artifacts generated by the examiner actions).

To avoid this, the **protect_rw** command just relabel the casper-rw partition to **casper-rw-protec** to keep CAINE for using it.

Of course, the CASPER non persistent boot option includes the **nopersistent** option to avoid thrashing any unprotected casper-rw partition

To protect the overlay partition (casper-rw partition), run:

```bash
./cafre protect_rw
```

##### Unprotect the overlay partition

This command undoes the changes done by **protect_rw**
It's not usually needed, unless you want to reuse a persistent partition that has been protected

To unprotect the overlay partition:

```bash
./cafre protect_rw
```

##### Wipe the overlay partition

This command wipes all data in the persistent overlay partition.
It should always be used while running in non persistent mode

It's useful when you have been testing the persistent mode to make sure data is kept in the overlay partition, and need to wipe it in order to have it clean for the acquisition process.

Remember that **for the forensic acquisition process, you must use the persistent boot option, but with a clean overlay partition, to avoid contaminating the artifacts with previous data**.

To wipe the persistent partition:

```bash
./cafre protect_rw
```

#### Hash and Timestamp management

These commands simplify the process of generating SHA256 hashes and signed timestamps

##### Generate hash for all files in directory

This command just generate the SHA256 hash recursively for all files in a given directory
The hashes are printed in standard output, so in order to have them in a file you need to redirect output

```
./cafre hash_dir DIRECTORY
```

##### Generate a FreeTSA signed timestamp for a file

This command gets a FreeTSA signed timestamp for a given file
This way it can be proved that the file as not been tampered with, and existed at that moment

It's very useful to "seal" the file with the SHA256 hashes for files or evidences.

```bash
./cafre timestamp file.txt
```

##### Verify a FreeTSA signed timestamp for a file

This command verifies a FreeTSA signed timestamp for a given file

It's used to verify the signature for a signed file. 

```bash
./cafre timestamp file.txt
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
