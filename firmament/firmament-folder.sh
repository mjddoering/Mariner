#!/bin/bash
version () {
	echo -e "\t     _                              _"
	echo -e "\t ___(_)                            | |_"
	echo -e "\t| __ _ _ _ _ __  __ _ _ __  ___ _ _|  _|"
	echo -e "\t| _|| | '_| '  \/ _' | '  \/ -_) ' \ |_"
    echo -e "\t|_| |_|_| |_|_|_\__,_|_|_|_\___|_||_\__|"
	echo -e "\t  Firmament, a part of the Mariner suite"
	echo -e "\t  Firmament for folders"
	echo -e "\t                       v. 0.2/2020.10.16\v"
	kill -INT $$
}
printERR () {
	printUsage
	echo -e "\v\tAn invalid option was provided; please check the command entered.\v"
	kill -INT $$ # Exit script after printing help, but not the shell
}
printHelp () {
	printUsage
	echo -e "\v\tThis script calls firmament.sh for each fasta file in the -p directory and"
	echo -e "\tadditionally removes short contigs.\v"
	kill -INT $$ # Exit script after printing help, but not the shell
}
printUsage () {
	echo -e "\t     _                              _"
	echo -e "\t ___(_)                            | |_"
	echo -e "\t| __ _ _ _ _ __  __ _ _ __  ___ _ _|  _|"
	echo -e "\t| _|| | '_| '  \/ _' | '  \/ -_) ' \ |_"
	echo -e "\t|_| |_|_| |_|_|_\__,_|_|_|_\___|_||_\__|"
	echo -e "\t  Firmament, a part of the Mariner suite"
	echo -e "\t  Firmament for folders"
	SCRIPTLOC="${BASH_SOURCE[0]}"
	echo -e "\tUsage: $SCRIPTLOC -s species -d desc -p directoryToParse -m minContigLength (default length 150)"
	echo -e "\tExample: $SCRIPTLOC -s Aratha -d simulation -p $HOME/Aratha/assemblies -m 150"
	echo -e "\tExample: $SCRIPTLOC -h\v"
}

while getopts :s:d:p:m:hv options; do
case $options in
	s) SPECIES=${OPTARG};;
	d) DESC=${OPTARG};;
	p) PROJECTDIR=${OPTARG};;
	m) MINLEN=${OPTARG};;
	h) printHelp;;
	v) version;;
	?) printERR;;
esac; done

if [[ $MINLEN == "" ]]; then
	MINLEN=150;
fi

PROJECTDIR1=$(rev <<< "$PROJECTDIR" | cut -d "/" -f 2- | cut -d "." -f 2- | rev)
ASSEMBLYDIR=$(rev <<< "$PROJECTDIR" | cut -d "/" -f 1 | cut -d "." -f 1 | rev)
OUTDIR="firmament"
mkdir -p $PROJECTDIR1/$OUTDIR/tmp
#for file in directory of format: assembler_[n]pk[1-9][1-9][1-9]
for FILE in $PROJECTDIR1/$ASSEMBLYDIR/*.fa; do
	OUTFILE=$(rev <<< "$FILE" | cut -d "/" -f 1 | cut -d "." -f 2- | rev)
	OUTF2=$(cut -d "_" -f 2 <<< "$OUTFILE" | cut -d "p" -f 2)
	A=$(cut -d "_" -f 1 <<< "$OUTFILE")
	if [[ $(cut -d "_" -f 2 <<< "$OUTFILE" | cut -d "p" -f 1) == "n" ]]; then
		N="TRUE"
		OUTFILE=$A"_HT"$OUTF2
	else
		N="FALSE"
		OUTFILE=$A"_HF"$OUTF2
	fi
	K=$(cut -d "_" -f 2 <<< "$OUTFILE" | cut -d "k" -f 2)
	reformat.sh in=$FILE out=$PROJECTDIR1/$OUTDIR/tmp/$OUTFILE.$MINLEN.fa minlength=$MINLEN
	cat $PROJECTDIR1/$OUTDIR/tmp/$OUTFILE.$MINLEN.fa | \
		firmament.sh -i - \
		-o $PROJECTDIR1/$OUTDIR/$OUTFILE.fa \
		-s $SPECIES -d $DESC \
		-a $A -n $N -k $K
done

echo "Finished $PROJECTDIR with exit code $? at: `date`"
