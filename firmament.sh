#!/bin/bash
version () {
	echo -e "\t     _                              _"
	echo -e "\t ___(_)                            | |_"
	echo -e "\t| __ _ _ _ _ __  __ _ _ __  ___ _ _|  _|"
	echo -e "\t| _|| | '_| '  \/ _' | '  \/ -_) ' \ |_"
    echo -e "\t|_| |_|_| |_|_|_\__,_|_|_|_\___|_||_\__|"
	echo -e "\t  Firmament, a part of the Mariner suite"
	echo -e "\t                       v. 0.2/2020.10.16\v"
	kill -INT $$
}

printHelp () {
	printUsage
	echo -e "\v\tFirmament consistently renames all contigs in a fasta file with"
	echo -e "\tno duplicate IDs. The file written by this script is ready to"
	echo -e "\tbe merged with other assemblers, with no risk of duplicate IDs, "
	echo -e "\tassuming no k-mer was used more than once per assembler (unless"
	echo -e "\tonce with normalized reads (use -n) and once with all reads).\v"

	echo -e "\t-i \tInput fasta file to rename"
	echo -e "\t     \treads from std in if -i - "
	echo -e "\t-o \tOutput fasta file to write"
	echo -e "\t     \tRequired, without extension, if fasta is submitted via stdin"
	echo -e "\t     \tWith -i, optional and uses the base input name by default"
	echo -e "\t     \tDefault output format is: baseh.fa (h added)"
	echo -e "\t     \tWith the wrapper script, to process all files in a directory,"
	echo -e "\t     \toutput is: assembler_H[TF]k[#]##.fa; T if normalized reads."
	echo -e "\t-s \t6 character species code"
	echo -e "\t     \tUse the first 3 letters of the genus followed by"
	echo -e "\t     \tthe first 3 letters of the specific epithet"
	echo -e "\t     \teg: Musmus for Mus musculus and"
	echo -e "\t     \tAratha for Arabidopsis thaliana"
	echo -e "\t-a \t4 character assembler code"
	echo -e "\t   \tSuggested codes for some assembers are:"
	echo -e "\t     \tBridger:\t\t BRID"
	echo -e "\t     \tBinPacker:\t\t BIPA"
	echo -e "\t     \tIDBA-tran:\t\t IDBA"
	echo -e "\t     \tOases:\t\t\t VEOA"
	echo -e "\t     \trnaSPAdes:\t\t RSPA"
	echo -e "\t     \tSOAPdenovo-Trans:\t SODT"
	echo -e "\t     \tTransABySS:\t\t TABY"
	echo -e "\t     \tTransLiG:\t\t TRLG"
	echo -e "\t     \tTrinity:\t\t TRIN"
	echo -e "\t-d \t10 character (max) description of the dataset"
	echo -e "\t-n \tFlag for whether the reads are normalized"
	echo -e "\t   \tUse TRUE if normalized reads were assembled, otherwise FALSE"
	echo -e "\t-k \tK-mer that was used in the assembly"
	echo -e "\t-h \tFlag to print this message\v"
	echo -e "\t-v \tDisplay the version of the script\v"
	kill -INT $$ # Exit script after printing help, but not the shell
}
printERR () {
	printUsage
	echo -e "\v\tAn invalid option was provided; please check the command entered.\v"
	kill -INT $$ # Exit script after printing help, but not the shell
}
printUsage () {
	echo -e "\t     _                              _"
	echo -e "\t ___(_)                            | |_"
	echo -e "\t| __ _ _ _ _ __  __ _ _ __  ___ _ _|  _|"
	echo -e "\t| _|| | '_| '  \/ _' | '  \/ -_) ' \ |_"
	echo -e "\t|_| |_|_| |_|_|_\__,_|_|_|_\___|_||_\__|"
	echo -e "\t  Firmament, a part of the Mariner suite"
	SCRIPTLOC="${BASH_SOURCE[0]}"
	echo -e "\tUsage: $SCRIPTLOC -i input.fa -s species -d desc -a assembler -n TRUE/FALSE -k kmer"
	echo -e "\tUsage: cat in.fa | $SCRIPTLOC -i - -o out.fa -s species -d desc -a assembler -n TRUE/FALSE -k kmer"
	echo -e "\tUsage: $SCRIPTLOC -h\v"
}

while getopts :i:o:s:a:d:n:k:hv options; do
case $options in
	i) INPUT=${OPTARG};;
	o) OUTFILE=${OPTARG};;
	s) SPECIES=${OPTARG};;
	a) ASSEMBLER=${OPTARG};;
	d) DESC=${OPTARG};;
	n) NORM=${OPTARG};;
	k) KMER=${OPTARG};;
	h) printHelp;;
	v) version;;
	?) printERR;;
esac; done

if [[ $INPUT == "" ]]; then
	printUsage;
	echo -e "\v\tPlease include an input fasta file.\v"; kill -INT $$
elif [[ ${#SPECIES} -ne 6 ]]; then
	printUsage
	echo -e "\v\tPlease provide a 6 characer string for the species ID.\v"; kill -INT $$
elif [[ ${#ASSEMBLER} -ne 4 ]]; then
	if [[ ${ASSEMBLER,,} == "bridger" ]]; then
		ASSEMBLER="BRID"
	elif [[ ${ASSEMBLER,,} == "binpacker" ]]; then
		ASSEMBLER="BIPA"
	elif [[ ${ASSEMBLER,,} == "idba-tran" ]]; then
		ASSEMBLER="IDBA"
	elif [[ ${ASSEMBLER,,} == "idbatran" ]]; then
		ASSEMBLER="IDBA"
	elif [[ ${ASSEMBLER,,} == "velvet" ]]; then
		ASSEMBLER="VEOA"
	elif [[ ${ASSEMBLER,,} == "oases" ]]; then
		ASSEMBLER="VEOA"
	elif [[ ${ASSEMBLER,,} == "velvet-oases" ]]; then
		ASSEMBLER="VEOA"
	elif [[ ${ASSEMBLER,,} == "spades" ]]; then
		ASSEMBLER="RSPA"
	elif [[ ${ASSEMBLER,,} == "rnaspades" ]]; then
		ASSEMBLER="RSPA"
	elif [[ ${ASSEMBLER,,} == "rna-spades" ]]; then
		ASSEMBLER="RSPA"
	elif [[ ${ASSEMBLER,,} == "soap" ]]; then
		ASSEMBLER="SODT"
	elif [[ ${ASSEMBLER,,} == "soapdenovo" ]]; then
		ASSEMBLER="SODT"
	elif [[ ${ASSEMBLER,,} == "soapdenovotrans" ]]; then
		ASSEMBLER="SODT"
	elif [[ ${ASSEMBLER,,} == "soapdenovo-trans" ]]; then
		ASSEMBLER="SODT"
	elif [[ ${ASSEMBLER,,} == "transabyss" ]]; then
		ASSEMBLER="TABY"
	elif [[ ${ASSEMBLER,,} == "trans-abyss" ]]; then
		ASSEMBLER="TABY"
	elif [[ ${ASSEMBLER,,} == "translig" ]]; then
		ASSEMBLER="TRLG"
	elif [[ ${ASSEMBLER,,} == "trinity" ]]; then
		ASSEMBLER="TRIN"
	else
		printUsage
		echo -e "\v\tPlease provide a 4 characer string for the assembler code,"
		echo -e "\tor a recognized assembler from the help list.\v"; kill -INT $$
	fi
elif [[ ${#DESC} -ge 11 ]]; then
	printUsage
	echo -e "\v\tPlease limit the dataset description to 10 characters.\v";  kill -INT $$
elif [[ $DESC == "" ]]; then
	printUsage
	echo -e "\v\tPlease provide a dataset description, with max 10 characters.\v"; kill -INT $$
elif [[ $NORM != "TRUE" && $NORM != "FALSE" ]]; then
	printUsage
	echo -e "\v\tPlease provide the -n flag for whether normalized reads were assembled.\v"; kill -INT $$
elif [[ $KMER == "" ]]; then
	printUsage
	echo -e "\v\tPlease provide the k-mer that was used in the assembly.\v"; kill -INT $$
elif ! [ $KMER -eq 1 -o "$KMER" -eq "$KMER" ] 2>/dev/null; then
	printUsage
	echo -e "\v\tPlease provide a valid k-mer (i.e. a number).\v"; kill -INT $$
fi

if [[ $INPUT == "-" ]]; then
	INPUT="${VAR:-/dev/stdin}"
	if [[ $OUTFILE == "" ]]; then
		printUsage
		echo -e "\v\tPlease enter the output file name, or pass the input file via the '-i' parameter.\v"; kill -INT $$
	fi
else
	if [[ $OUTFILE == "" ]]; then
		OUTFILE=$(rev <<< "$INPUT" | cut -d "." -f 2- | rev)
		OUT1="$OUTFILE"h.fa
		OUTFILE=$OUT1
	fi
fi

SPECIESL=${SPECIES,,}
SPECIESU=${SPECIESL^}
DESCU=${DESC^}
ASSEMBLERU=${ASSEMBLER^^}

if [[ $NORM == "TRUE" ]]; then
	NORML="T"
else
	NORML="F"
fi
if [[ ${#KMER} == 2 ]]; then
	KMERN="0"$KMER
else
	KMERN=$KMER
fi

sed -e '/^>/s/$/@/' -e 's/^>/#/' $INPUT | \
	sed -e '/^-/s/^-.*/\t/' | \
	tr -d '\n' | tr "#" "\n" | \
	sed '/^\s*$/d' | tr "@" "\t" | \
	sed -e 's/^/>/' -e 's/\t/\n/' | \
	sed -E "s/([ACGT])(>)/\1\n\2/g" | \
	awk -F">" -v SP=$SPECIESU -v AS=$ASSEMBLERU -v DE=$DESCU -v NL=$NORML -v KN=$KMERN '/^>/{print ">"SP""DE""AS""++i""NL"k"KN " " $2; next}{print}' \
	> "$OUTFILE"
