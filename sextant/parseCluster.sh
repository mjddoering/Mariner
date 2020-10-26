#!/bin/bash -ve
ASSEMBLER1ID="IDBA" #idba
ASSEMBLER2ID="RSPA" #spades here
ASSEMBLER3ID="SODT" #soap
ASSEMBLER4ID="TRLG" #translig
ASSEMBLER5ID="TRIN" #trinity
NBCLUSTER="-1"
NBITEM=0
REFSEQ=""
A1F=0
A2F=0
A3F=0
A4F=0
A5F=0
NUMASSEMBLERS=0

while getopts :o: options; do
case $options in
	o) OUTFILE=${OPTARG};;
esac; done

while read -r line; do
	#check if its the first line of a cluster
	if [[ ${line:0:1} == '>' ]]; then 
		#check if its the first line of the file, if not then write summary of previous cluster
		if [[ $NBCLUSTER -ge 0 ]]; then 
			NUMASSEMBLERS=$((A1F+A2F+A3F+A4F+A5F))
			echo $REFSEQ,$NBCLUSTER,$NBITEM,$A1F,$A2F,$A3F,$A4F,$A5F,$NUMASSEMBLERS >> $OUTFILE
		fi
		#extract the cluster number from the .clstr file itself
		NBCLUSTER=$(echo $line | cut -d " " -f 2 )
		NBITEM=0
		A1F=0
		A2F=0
		A3F=0
		A4F=0
		A5F=0
		REFSEQ=''
	else 
		((NBITEM++))
		if echo $line | grep $ASSEMBLER1ID; then 
			A1F=1
		elif echo $line | grep $ASSEMBLER2ID; then 
			A2F=1
		elif echo $line | grep $ASSEMBLER3ID; then 
			A3F=1
		elif echo $line | grep $ASSEMBLER4ID; then 
			A4F=1
		elif echo $line | grep $ASSEMBLER5ID; then 
			A5F=1
		fi
		#searching for the 3 dots, a space, and a NON-a character (ie asterisk)
		if echo $line |  grep "\.\.\. [^a]"; then
			REFSEQ=$(echo $line | cut -d ">" -f 2 | cut -d "." -f 1)
		fi
	fi
done <${VAR:-/dev/stdin}
#write data for final cluster, becuase no ">" symbol to detect at end of file
NUMASSEMBLERS=$((A1F+A2F+A3F+A4F+A5F))
echo $REFSEQ,$NBCLUSTER,$NBITEM,$A1F,$A2F,$A3F,$A4F,$A5F,$NUMASSEMBLERS >> $OUTFILE





