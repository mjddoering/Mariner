#!/usr/bin/bash
#todo
	# might split out AntiFam to separate function

#######################################
# Default parameters adjustable on command line
DEFIN="firmament/*fa" #input directory
DEFC="FALSE" #run consensus
DEFE="FALSE" #run evigene
DEFF="FALSE" #run TPM filtering
DEFT="FALSE" #run Transfuse
DEFD="FALSE" #run Detonate
DEFI="FALSE" #run Corset
DEFSUM="FALSE" #run summary stats
DEFROOT="Mariner" #root name for output files
DEFREADLEN=125 #read length, used by Detonate
DEFN=4 #number of threads
DEFM=250000 #max memory, in MB; used by evigene and cd-hit-est

# Values required by programs, not intended for willy-nilly adjustment
OUTDIR="Mariner" #output directory, each program writes to a sub directory
MINEVICDS=45 #min ORF length, used by evigene
CONCDHIT=1.0 #% identity used in consensus merging of multiple assemblies
SALMONK=25 #k used by Salmon in TPM filtering and Salmon stage of preparation for Corset
THRESHOLD=0 #TPM filtering threshold used by Salmon
CORSETD="0,0.3,1" #list of distance values to use in Corset isoform merging
SALMONDIR="/home/mariner/software/salmon-1.4.0/bin" #path to version of Salmon to run for TPM filtering and Corset; salmon installed to PATH is v 0.4.0 needed for Transfuse

#######################################
# The programs are run in the following order:
#	0. Firmament (rename contigs to ensure no duplicate names in the constellation)
#		run separately, if required
#	1. Consensus (recommended if assembly space of multiple assemblers is thoroughly explored)
#		(ie multi-k, with and without normalized reads)
#		preferred approach: Consensus2 based on usage of five assemblers
#	2. EvidentialGene (recommended with very large numbers of contigs, eg at least millions or tens of millions)
#	3. TPM>0 (Salmon) (recommended if Transfuse fails, eg during read alignment)
#	4. Transfuse (a core part of the Mariner pipeline)
#	5. Detonate (a core part of the Mariner pipeline, optional but recommended)
#	6. Corset (optional, depending on experimental needs)
#	7. Describe contig sets

#######################################
version () {
	printVersion
	kill -INT $$
}
printVersion () {
	echo -e "\t   ___          _            _"
	echo -e "\t  / __| _____ _| |_ __ _ _ _| |______"
	echo -e "\t _\__ \/ -_) \ /  _/ _' | ' \  ______|"
	echo -e "\t|_____/\___/_\_\\\\\\__\__,_|_||_\__|"
	echo -e "\t  Sextant, a part of the Mariner suite"
	echo -e "\t                     v. 0.1c/2021.04.14\v"
}

#######################################
printHelp () {
	printUsage
	echo -e "\v\tSextant removes redundancy from a single fasta file, or an overassembled set."
	echo -e "\tRecommendations are to run Transfuse then Detonate; if Transfuse fails then:"
	echo -e "\tRun TPM filtering (ie remove contigs with TPM=0, any method can be used though"
	echo -e "\tthe Mariner pipeline used Salmon's mapping-based mode.)"
	echo -e "\tIf Transfuse still fails to run, Detonate may be run directly on the TPM filtered"
	echo -e "\tset of contigs."
	echo -e "\t"
	echo -e "\tIf the assembly space of 5 assemblers has been thorough explored, ie full range of"
	echo -e "\tk-mers with both trimmed and normalized trimmed reads, then consensus-based filtering"
	echo -e "\tshould be the first step run. Mariner uses con2 (contigs assembled by 2 or more methods)."
	echo -e "\t"
	echo -e "\tEvigene can be useful to effeciently filter through many millions or tens of millions of"
	echo -e "\tcontigs, as an additional method made available through the Mariner implementation of"
	echo -e "\tredundancy removal tools."
	echo -e "\t"
	echo -e "\t\t-i	Path to input fasta files or files,"
	echo -e "\t\t     \teg: path/to/input.fa or path/to/*.fa;"
	echo -e "\t\t     \tdefault is ./Firmament/*fa"
	echo -e "\t\t-1	Path to forward reads, used by Transfuse, Salmon, Detonate, Corset"
	echo -e "\t\t-2	Path to reverse reads, used by Transfuse, Salmon, Detonate, Corset"
	echo -e "\t\t-o \tPrefix to label all files with. Output is written to ./Mariner and"
	echo -e "\t\t     \tsubdirectories therein"
	echo -e "\t\t-c	Flag to run consensus based filtering; default (no flag) is do not run"
	echo -e "\t\t-e	Flag to run EvidentialGene filtering; default (no flag) is do not run"
	echo -e "\t\t-f	Flag to run expression filtering (remove contigs with TPM=0"
	echo -e "\t\t     \tbased on Salmon alignment); default is do not run"
	echo -e "\t\t-t	Flag to run Transfuse filtering; default is do not run"
	echo -e "\t\t-d	Flag to run Detonate contig filtering; default is do not run"
	echo -e "\t\t  -p	Path to Detonate parameter file; if omitted it will be"
	echo -e "\t\t     \tcreated based on the contig sequences (not ideal)"
	echo -e "\t\t  -r	Read length, used by Detonate"
	echo -e "\t\t-g	Flag to run Corset isoform grouping, default is do not run"
	echo -e "\t\t-s	Flag to run summary stats, if this is the only flag set"
	echo -e "\t\t     \tthen it runs summary stats on all *.fa files in the specified"
	echo -e "\t\t     \tdirectory, otherwise runs summaries on files produced in earlier"
	echo -e "\t\t     \tsteps of that Sextant run. Default, no flag, is do not run summaries"
	echo -e "\t\t  -X	Number of bases in contig set / assembly / simulation to use"
	echo -e "\t\t     \tfor Nx_s and Lx_s calculations ( x in 1..(len(fa)/X) )"
	echo -e "\t\t-n	Number of threads available to run in parallel"
	echo -e "\t\t-m	Memory available to be used (in Mb)"
	echo -e "\t\t-h Flag to print this message"
	echo -e "\t\t-v Display the version of the script"
	echo -e "\t\tAdditional parameters may be configured at the start of the script.\v"
	kill -INT $$
}

#######################################
printERR () {
	printUsage
	echo -e "\v\tAn invalid option was provided; please check the command entered.\v"
	kill -INT $$ # Exit script after printing help, but not the shell
}

#######################################
printUsage () {
	printVersion
	SCRIPTLOC="${BASH_SOURCE[0]}"
	echo -e "\tRun Consensus: $SCRIPTLOC -i Firmament/*.fa -o Dataset1 -c -n 4 -m 256000"
	echo -e "\tRun Transfuse: $SCRIPTLOC -i Mariner/output/Dataset1.01.consensus2.tr.fa -1 path/to/reads1.fq -2 path/to/reads2.fq -o Dataset1 -t -n 4"
	echo -e "\tRun Detonate: $SCRIPTLOC -i Mariner/output/Dataset1.04c.TF3.fa -1 path/to/reads1.fq -2 path/to/read2.fq -o Dataset1 -d -p path/to/paramFile -n 4"
	echo -e "\tRun Corset: $SCRIPTLOC -i Mariner/output/Dataset1.05.Detonate.fa -1 path/to/reads1.fq -2 path/to/read2.fq -o Dataset1 -g -p path/to/paramFile -n 4"
	echo -e "\tUsage: $SCRIPTLOC -h"
	echo -e "\tUsage: $SCRIPTLOC -v"
}

CONSENSUS=""
EVIGENE=""
TPM=""
TRANSFUSE=""
DETONATE=""
CORSET=""
SUMMARY=""
READLEN=""
DETPARAM=""
SUMMREFX=""

while getopts :i:1:2:o:ceftdp:r:gsX:n:m:hv OPTIONS; do
case $OPTIONS in
	i) INPUT=${OPTARG};;
	1) READS1=${OPTARG};;
	2) READS2=${OPTARG};;
	o) FILEROOT=${OPTARG};;
	c) CONSENSUS=TRUE;;
	e) EVIGENE=TRUE;;
	f) TPM=TRUE;;
	t) TRANSFUSE=TRUE;;
	d) DETONATE=TRUE;;
	p) DETPARAM=${OPTARG};;
	r) READLEN=${OPTARG};;
	g) CORSET=TRUE;;
	s) SUMMARY=TRUE;;
	X) SUMMREFX=${OPTARG};;
	n) THREADS=${OPTARG};;
	m) MEM=${OPTARG};;
	h) printHelp;;
	v) version;;
	?) printERR;;
esac; done

#######################################
# Get user run requests and display messages as needed
if [[ $INPUT == "" ]]; then
	#printUsage;
	#echo -e "\v\tPlease include an input directory.\v"; kill -INT $$
	INPUT=$DEFIN
fi
if [[ $FILEROOT == "" ]]; then
	FILEROOT=$DEFROOT
fi
if [[ $CONSENSUS == "" ]]; then
	CONSENSUS=$DEFC
	MARINER1="Run Consensus-based merge:\tNo"
else
	MARINER1="Run Consensus-based merge:\tYes"
fi
if [[ $EVIGENE == "" ]]; then
	EVIGENE=$DEFE
	MARINER2="Run EvidentialGene filtering:\tNo"
else
	MARINER2="Run EvidentialGene filtering:\tYes"
fi
if [[ $TPM == "" ]]; then
	TPM=$DEFF
	MARINER3="Run TPM expression filtering:\tNo"
else
	MARINER3="Run TPM expression filtering:\tYes"
fi
if [[ $TRANSFUSE == "" ]]; then
	TRANSFUSE=$DEFT
	MARINER4="Run Transfuse filtering:\tNo"
else
	MARINER4="Run Transfuse filtering:\tYes"
fi
if [[ $DETONATE == "" ]]; then
	DETONATE=$DEFD
	MARINER5="Run Detonate contig removal:\tNo"
else
	MARINER5="Run Detonate contig removal:\tYes"
fi
if [[ $READLEN == "" ]]; then
	READLEN=$DEFREADLEN
fi
if [[ $CORSET == "" ]]; then
	CORSET=$DEFI
	MARINER6="Run Corset isoform merge:\tNo"
else
	MARINER6="Run Corset isoform merge:\tYes"
fi
if [[ $SUMMARY == "" ]]; then
	SUMMARY=$DEFSUM
	MARINER7="Report contig set summaries:\tNo"
else
	MARINER7="Report contig set summaries:\tYes"
fi
if [[ $THREADS == "" ]]; then
	THREADS=$DEFN
fi
if [[ $MEM == "" ]]; then
	MEM=$DEFM
fi

#if output report file exists, end script
mkdir -p $OUTDIR
REPFILE="$OUTDIR/Mariner.report.txt"
# thought about disallowing Mariner to run if using a prior output directory
# 	currently not used as each set of output goes to a different subdirectory within $OUTDIR
#if [[ -f "$REPFILE" ]]; then
#	printVersion
#	echo -e "Output file $OUTDIR/Mariner.report.txt exists"
#	echo -e "Please clean up prior output or specify an empty output directory with the -o option"
#	kill -INT $$
#else
	touch $REPFILE
	printVersion
	printVersion >> $REPFILE
	echo -e "Mariner setting sail at $(date)\n"
	echo -e "Mariner setting sail at $(date)\n" >> $REPFILE
	echo -e "\t$MARINER1\n\t$MARINER2\n\t$MARINER3\n\t$MARINER4\n\t$MARINER5\n\t$MARINER6\n\n\t$MARINER7\n"
	echo -e "\t$MARINER1\n\t$MARINER2\n\t$MARINER3\n\t$MARINER4\n\t$MARINER5\n\t$MARINER6\n\n\t$MARINER7\n" >> $REPFILE
#fi

#######################################
#	Reusable functions                #
#######################################

#######################################
# A. Linearize fasta
#	accepts 2 arguments: "file.fa" "file.lin.fa"
#	sorting stage added to avoid some failure situations with the grepFA function
linearizeFA () {
	sed -e '/^>/s/$/@/' -e 's/^>/#/' $1 | \
		sed -e '/^-/s/^-.*/\t/' | \
		tr -d '\n' | \
		tr "#" "\n" |
		sort | \
		sed '/^\s*$/d' | \
		tr "@" "\t" | \
		sed -e 's/^/>/' -e 's/\t/\n/' | \
		sed -E "s/([ACGT])(>)/\1\n\2/g" | \
		sed 's/[[:blank:]]*$//' \
		> $2
}

#######################################
# B. grep sequences from contig ID list then linearize
#	accepts 2 arguments: "seq.id" "output.fa"
grepFA () {
	grep -A 1 -wFf $1 $INPUT | \
		sed -e '/^>/s/$/@/' -e 's/^>/#/' | \
		sed -e '/^-/s/^-.*/\t/' | \
		tr -d '\n' | \
		tr "#" "\n" | \
		sed '/^\s*$/d' | \
		tr "@" "\t" | \
		sed -e 's/^/>/' -e 's/\t/\n/' | \
		sed -E "s/([ACGT])(>)/\1\n\2/g" | \
		sed 's/[[:blank:]]*$//' \
		> $2
# grep -A 1 -wFf $1 $INPUT | sed -e '/^>/s/$/@/' -e 's/^>/#/' | sed -e '/^-/s/^-.*/\t/' | tr -d '\n' | tr "#" "\n" | sed '/^\s*$/d' | tr "@" "\t" | sed -e 's/^/>/' -e 's/\t/\n/' | sed -E "s/([ACGT])(>)/\1\n\2/g" | sed 's/[[:blank:]]*$//' > $2
	LINESID=$(sed "/transcript_id/d" $1 | wc -l)
	SEQFA=$(grep -c "^>" $2)
	if [[ $LINESID == $SEQFA ]]; then
		echo -e "$SEQFA sequences written to $2"
		echo -e "$SEQFA sequences written to $2" >> $REPFILE
	else
		echo -e "check grep output and allocate more memory if necessary to write subsetted sequences to $2"
		echo -e "check grep output and allocate more memory if necessary to write subsetted sequences to $2" >> $REPFILE
		kill -INT $$
	fi
}

#######################################
# C. calculate contig lengths, #contigs in a fasta file
#	accepts 1 argument: input.lin.fa
lenCal () {
	awk -F' ' '/^>/{printf substr($1,2) "\t"; next}{seqlen=length($0); print seqlen}' $1 | sort -nrk2,2 > $1.len.tsv
}

#######################################
# D. check that the read files exist, other write error message and exit
checkReads () {
	if [[ -f "$READS1" ]]; then
		echo -e "Reads 1 file found: $READS1"
		echo -e "Reads 1 file found: $READS1" >> $REPFILE
	else
		echo -e "Please ensure that $READS1 exists"
		echo -e "Currently Mariner expects both forward and reverse reads as unzipped fastq files"
		echo -e "Please ensure that $READS1 exists" >> $REPFILE
		echo -e "Currently Mariner expects both forward and reverse reads as unzipped fastq files" >> $REPFILE
		kill -INT $$
	fi
	if [[ -f "$READS2" ]]; then
		echo -e "Reads 2 file found: $READS2"
		echo -e "Reads 2 file found: $READS2" >> $REPFILE
	else
		echo -e "Please ensure that $READS2 exists"
		echo -e "Currently Mariner expects both forward and reverse reads as unzipped fastq files"
		echo -e "Please ensure that $READS2 exists" >> $REPFILE
		echo -e "Currently Mariner expects both forward and reverse reads as unzipped fastq files" >> $REPFILE
		kill -INT $$
	fi
	FILETYPE1=$(rev <<< "$READS1" | cut -d "." -f1 | rev)
	FILETYPE2=$(rev <<< "$READS2" | cut -d "." -f1 | rev)
	if [[ $FILETYPE1 != "fq" || $FILETYPE2 != "fq" ]]; then
		echo -e "Please ensure that both read files are provided as unzipped fastq files (expecting *.fq file name)"
		echo -e "Please ensure that both read files are provided as unzipped fastq files (expecting *.fq file name)" >> $REPFILE
		kill -INT $$
	fi
}

#######################################
# E. cat input and linearize
parseInput () {
	# create the input file; can be a list in the form dir/*fa
	mkdir -p $OUTDIR/input
	echo $INPUT
	cat $INPUT > $OUTDIR/input/$FILEROOT.fa
	linearizeFA "$OUTDIR/input/$FILEROOT.fa" "$OUTDIR/input/$FILEROOT.lin.fa"
	echo -e "$(date) parsing input completed" >> $REPFILE
}

#######################################
#	Mariner methods                   #
#######################################

#######################################
# 1. Consensus
consensual () {
	echo -e "##################"
	echo -e "##################" >> $REPFILE
	echo -e started Consensus-based merge at $(date) for $INPUT : "cd-hit-est -M $MEM -T $THREADS -d 0 -c $CONCDHIT -i $INPUT -o $OUTDIR/01-consensus/$FILEROOT.c$CONCDHIT.fa"
	echo -e started Consensus-based merge at $(date) for $INPUT : "cd-hit-est -M $MEM -T $THREADS -d 0 -c $CONCDHIT -i $INPUT -o $OUTDIR/01-consensus/$FILEROOT.c$CONCDHIT.fa" >> $REPFILE
	cd-hit-est -M $MEM -T $THREADS -d 0 -c $CONCDHIT \
		-i $INPUT \
		-o $OUTDIR/01-consensus/$FILEROOT.c$CONCDHIT.fa
	echo -e "\tstarted Consensus-based merge at" $(date) for $INPUT : "parallel processing of cluster"
	echo -e "\tstarted Consensus-based merge at" $(date) for $INPUT : "parallel processing of cluster" >> $REPFILE
	#don't use just ">" for recstart as that will match seq IDs onevery line midway through
	parallel -j $THREADS -k --block -1 --recstart '>Cluster ' --pipepart ". parseCluster.sh -o $OUTDIR/01-consensus/$FILEROOT.csv" :::: $OUTDIR/01-consensus/$FILEROOT.c$CONCDHIT.fa.clstr
	echo -e "\tstarted Consensus-based merge at" $(date) for $INPUT : "final file parsing"
	echo -e "\tstarted Consensus-based merge at" $(date) for $INPUT : "final file parsing" >> $REPFILE
	#parse new csv file written by the above echo statements
	#  to get the sequences assembled by 2, 3, 4, and 5 of the assemblers
	grep ",2$" $OUTDIR/01-consensus/$FILEROOT.csv > $OUTDIR/01-consensus/$FILEROOT.csv2
	grep ",3$" $OUTDIR/01-consensus/$FILEROOT.csv > $OUTDIR/01-consensus/$FILEROOT.csv3
	grep ",4$" $OUTDIR/01-consensus/$FILEROOT.csv > $OUTDIR/01-consensus/$FILEROOT.csv4
	grep ",5$" $OUTDIR/01-consensus/$FILEROOT.csv > $OUTDIR/01-consensus/$FILEROOT.csv5
	#then merge together to form the consensus2...consensus5 files desired
	cat $OUTDIR/01-consensus/$FILEROOT.csv2 $OUTDIR/01-consensus/$FILEROOT.csv3 $OUTDIR/01-consensus/$FILEROOT.csv4 $OUTDIR/01-consensus/$FILEROOT.csv5 > $OUTDIR/01-consensus/$FILEROOT.consensus2.csv
	cat $OUTDIR/01-consensus/$FILEROOT.csv3 $OUTDIR/01-consensus/$FILEROOT.csv4 $OUTDIR/01-consensus/$FILEROOT.csv5 > $OUTDIR/01-consensus/$FILEROOT.consensus3.csv
	cat $OUTDIR/01-consensus/$FILEROOT.csv4 $OUTDIR/01-consensus/$FILEROOT.csv5 > $OUTDIR/01-consensus/$FILEROOT.consensus4.csv
	#get the IDs from each consensus set
	#additional parsing step needed for concat consensus as that's coming from clustering of ORFs
	#cut -d "|" -f 2 | cut -d ":" -f 1
	cut -d "," -f 1 $OUTDIR/01-consensus/$FILEROOT.consensus2.csv | sort -u > $OUTDIR/01-consensus/$FILEROOT.consensus2.id
	cut -d "," -f 1 $OUTDIR/01-consensus/$FILEROOT.consensus3.csv | sort -u > $OUTDIR/01-consensus/$FILEROOT.consensus3.id
	cut -d "," -f 1 $OUTDIR/01-consensus/$FILEROOT.consensus4.csv | sort -u > $OUTDIR/01-consensus/$FILEROOT.consensus4.id
	cut -d "," -f 1 $OUTDIR/01-consensus/$FILEROOT.csv5 | sort -u > $OUTDIR/01-consensus/$FILEROOT.consensus5.id

	#grep to get the sequences in each set from the parent assembly file
	grepFA "$OUTDIR/01-consensus/$FILEROOT.consensus2.id" "$OUTDIR/01-consensus/$FILEROOT.consensus2.tr.fa"
	grepFA "$OUTDIR/01-consensus/$FILEROOT.consensus3.id" "$OUTDIR/01-consensus/$FILEROOT.consensus3.tr.fa"
	grepFA "$OUTDIR/01-consensus/$FILEROOT.consensus4.id" "$OUTDIR/01-consensus/$FILEROOT.consensus4.tr.fa"
	grepFA "$OUTDIR/01-consensus/$FILEROOT.consensus5.id" "$OUTDIR/01-consensus/$FILEROOT.consensus5.tr.fa"

	echo -e "completed Consensus-based merge at" $(date) for $INPUT
	echo -e "completed Consensus-based merge at" $(date) for $INPUT >> $REPFILE
}

#######################################
# 2. EvidentialGene, with Antifam screening of ORFs of ok+cull
evidencing () {
	FAFILE=$(rev <<< "$INPUT" | cut -d "/" -f1 | cut -d "." -f2- | rev)
	echo -e "##################"
	echo -e "##################" >> ../../$REPFILE
	echo -e started EvidentialGene filtering at $(date) for $INPUT : "tr2aacds4.pl -mrnaseq $FAFILE.fa -NCPU=$THREADS -MAXMEM=$MEM -logfile -tidyup -MINCDS=$MINEVICDS"
	echo -e started EvidentialGene filtering at $(date) for $INPUT : "tr2aacds4.pl -mrnaseq $FAFILE.fa -NCPU=$THREADS -MAXMEM=$MEM -logfile -tidyup -MINCDS=$MINEVICDS" >> ../../$REPFILE
	tr2aacds4.pl -cdnaseq $FAFILE.fa -NCPU=$THREADS -MAXMEM=$MEM -logfile -tidyup -MINCDS=$MINEVICDS

	echo -e "\tstarted EvidentialGene filtering at" $(date) for $INPUT : "file parsing"
	echo -e "\tstarted EvidentialGene filtering at" $(date) for $INPUT : "file parsing" >> ../../$REPFILE
	cat okayset/$FAFILE.okay.*aa okayset/$FAFILE.okalt.*aa > okayset/$FAFILE.evi4Full.aa
	cat okayset/$FAFILE.okay.*cds okayset/$FAFILE.okalt.*cds > okayset/$FAFILE.evi4Full.cds
	cat okayset/$FAFILE.okay.tr okayset/$FAFILE.okalt.tr > okayset/$FAFILE.evi4Full.tr
	#linearize ok set and full set, from okay (2nd pass) directory
	linearizeFA "okayset/$FAFILE.okay.*aa" "../../$OUTDIR/02-evigene/$FAFILE.evi4Okay.aa"
	linearizeFA "okayset/$FAFILE.okay.*cds" "../../$OUTDIR/02-evigene/$FAFILE.evi4Okay.cds"
	linearizeFA "okayset/$FAFILE.okay.tr" "../../$OUTDIR/02-evigene/$FAFILE.evi4Okay.tr"
	linearizeFA "okayset/$FAFILE.evi4Full.aa" "../../$OUTDIR/02-evigene/$FAFILE.evi4Full.aa"
	linearizeFA "okayset/$FAFILE.evi4Full.cds" "../../$OUTDIR/02-evigene/$FAFILE.evi4Full.cds"
	linearizeFA "okayset/$FAFILE.evi4Full.tr" "../../$OUTDIR/02-evigene/$FAFILE.evi4Full.tr"
	cd $WD

	################ AntiFam
	mkdir -p $OUTDIR/02-evigene/AntiFam

	echo -e "\tstarted AntiFam hmmsearch at" $(date) for $INPUT : "hmmsearch --cpu $THREADS --tblout $OUTDIR/02-evigene/AntiFam/hmmsearch.$FAFILE.tblout.txt --domtblout $OUTDIR/02-evigene/AntiFam/hmmsearch.$FAFILE.domtblout.txt -o $OUTDIR/02-evigene/AntiFam/hmmsearch.$FAFILE.out.txt --noali --cut_ga /home/mariner/software/AntiFam_6.0/AntiFam_Eukaryota.hmm $OUTDIR/02-evigene/$FAFILE.evi4Full.aa"
	echo -e "\tstarted AntiFam hmmsearch at" $(date) for $INPUT : "hmmsearch --cpu $THREADS --tblout $OUTDIR/02-evigene/AntiFam/hmmsearch.$FAFILE.tblout.txt --domtblout $OUTDIR/02-evigene/AntiFam/hmmsearch.$FAFILE.domtblout.txt -o $OUTDIR/02-evigene/AntiFam/hmmsearch.$FAFILE.out.txt --noali --cut_ga /home/mariner/software/AntiFam_6.0/AntiFam_Eukaryota.hmm $OUTDIR/02-evigene/$FAFILE.evi4Full.aa" >> $REPFILE
	hmmsearch --cpu $THREADS \
		--tblout $OUTDIR/02-evigene/AntiFam/hmmsearch.$FAFILE.tblout.txt \
		--domtblout $OUTDIR/02-evigene/AntiFam/hmmsearch.$FAFILE.domtblout.txt \
		-o $OUTDIR/02-evigene/AntiFam/hmmsearch.$FAFILE.out.txt \
		--noali \
		--cut_ga \
		/home/mariner/software/AntiFam_6.0/AntiFam_Eukaryota.hmm \
		$OUTDIR/02-evigene/$FAFILE.evi4Full.aa

		echo -e "\tstarted AntiFam hmmsearch at" $(date) for $INPUT : "parsing output"
		echo -e "\tstarted AntiFam hmmsearch at" $(date) for $INPUT : "parsing output" >> $REPFILE
		awk '{print $1}' $OUTDIR/02-evigene/AntiFam/hmmsearch.$FAFILE.tblout.txt | sort -u > $OUTDIR/02-evigene/AntiFam/hmmsearch.$FAFILE.tblout.txt.id
		grep "^>" $OUTDIR/02-evigene/$FAFILE.evi4Full.aa | cut -d " " -f 1 | cut -d ">" -f 2 > $OUTDIR/02-evigene/AntiFam/$FAFILE.id
		#get IDs that are unique to assembly set of IDs
		comm -13 <(sort $OUTDIR/02-evigene/AntiFam/hmmsearch.$FAFILE.tblout.txt.id) <(sort $OUTDIR/02-evigene/AntiFam/$FAFILE.id) > $OUTDIR/02-evigene/AntiFam/$FAFILE.AF.id
		sed -e 's/utrorf//' $OUTDIR/02-evigene/AntiFam/$FAFILE.AF.id | sort -u > $OUTDIR/02-evigene/AntiFam/$FAFILE.AF.tr.id

		NUMAF=$(comm -12 $OUTDIR/02-evigene/AntiFam/hmmsearch.$FAFILE.tblout.txt.id <(sort $OUTDIR/02-evigene/AntiFam/$FAFILE.id) | wc -l)
		echo "Number of AntiFam hits among translated coding sequences in $FAFILE.evi4Full.aa: $NUMAF"

		#extract the sequences passing the Antifam filter, remove this is the goal is just to count ORFs that fail the step
		#cut the .aa extension and add the .tr extension for the full mrna sequence dataset
		grepFA "$OUTDIR/02-evigene/AntiFam/$FAFILE.AF.tr.id" "$OUTDIR/02-evigene/AntiFam/$FAFILE.AF.tr.fa"
		grepFA "$OUTDIR/02-evigene/AntiFam/$FAFILE.AF.tr.id" "$OUTDIR/02-evigene/AntiFam/$FAFILE.AF.aa.fa"
		grepFA "$OUTDIR/02-evigene/AntiFam/$FAFILE.AF.tr.id" "$OUTDIR/02-evigene/AntiFam/$FAFILE.AF.cds.fa"

		#older versions of evigene renamed contigs, no longer seems to be the case
		#code to rename contigs back to original names has been removed
		NUMEVIFTR=$(grep -c "^>" $OUTDIR/02-evigene/$FAFILE.evi4Full.tr)
		NUMAFTR=$(grep -c "^>" $OUTDIR/02-evigene/AntiFam/$FAFILE.AF.tr.fa)
		echo -e "\tNumber transcripts in evigene4 Full output: $NUMEVIFTR"
		echo -e "\tNumber transcripts in evi4Full-->AntiFam output: $NUMAFTR"
		echo -e "\tNumber transcripts in evigene4 Full output: $NUMEVIFTR" >> $REPFILE
		echo -e "\tNumber transcripts in evi4Full-->AntiFam output: $NUMAFTR" >> $REPFILE

		echo -e "completed EvidentialGene filtering at" $(date) for $INPUT
		echo -e "completed EvidentialGene filtering at" $(date) for $INPUT >> $REPFILE
}

#######################################
# 3. TPM filtering
filtering () {
	echo -e "##################"
	echo -e "##################" >> $REPFILE
	echo -e "started Salmon TPM filtering at $(date) for $INPUT: salmon index"
	echo -e "started Salmon TPM filtering at $(date) for $INPUT: salmon index" >> $REPFILE
	SALMONVER=$($SALMONDIR/salmon -v | cut -d" " -f2-)
	if [[ $SALMONVER != "" ]]; then
		echo -e "\trunning salmon version $SALMONVER ... proceeding"
		echo -e "\trunning salmon version $SALMONVER ... proceeding" >> $REPFILE
	else
		echo -e "\tyou may be running the out of date Salmon used by Transfuse ... attempting to proceed"
		echo -e "\tyou may be running the out of date Salmon used by Transfuse ... attempting to proceed" >> $REPFILE
	fi
	$SALMONDIR/salmon index -p $THREADS \
		-t $INPUT \
		-i $OUTDIR/03-TPMfiltering/index \
		-k $SALMONK
	echo $(date) salmon index completed

	#check that the read files exist
	checkReads

	echo -e "\tread files found"
	echo -e "\tread files found" >> $REPFILE
	echo -e "\tstarted Salmon TPM filtering at $(date) for $INPUT: salmon quant"
	echo -e "\tstarted Salmon TPM filtering at $(date) for $INPUT: salmon quant" >> $REPFILE
	#salmon to align reads
	$SALMONDIR/salmon quant -i $OUTDIR/03-TPMfiltering/index \
		-l A \
		-1 $READS1 \
		-2 $READS2 \
		--validateMappings \
		-p $THREADS \
		-o $OUTDIR/03-TPMfiltering

	echo -e "\tstarted Salmon TPM filtering at $(date) for $INPUT: file parsing"
	echo -e "\tstarted Salmon TPM filtering at $(date) for $INPUT: file parsing" >> $REPFILE
	awk -v TPM=0 '$4>TPM' $OUTDIR/03-TPMfiltering/quant.sf \
		> $OUTDIR/03-TPMfiltering/quant.tpm0.sf
	cut -f 1 $OUTDIR/03-TPMfiltering/quant.tpm0.sf | sed '1d' > $OUTDIR/03-TPMfiltering/$FILEROOT.tpm0.id
	grepFA "$OUTDIR/03-TPMfiltering/$FILEROOT.tpm0.id" "$OUTDIR/03-TPMfiltering/$FILEROOT.tpm0.fa"

	echo -e "completed Salmon TPM filtering at" $(date) for $INPUT
	echo -e "completed Salmon TPM filtering at" $(date) for $INPUT >> $REPFILE
}

#######################################
# 4. Transfuse
transfusing () {
	echo -e "##################"
	echo -e "##################" >> ../../$REPFILE
	echo -e "started Transfuse filtering at $(date) for $INPUT"
	echo -e "started Transfuse filtering at $(date) for $INPUT" >> ../../$REPFILE

	FAFILE=$(rev <<< "$INPUT" | cut -d "/" -f1 | cut -d "." -f2- | rev)

	transfuse --install

	transfuse -a ../../$INPUT \
		-l ../../$READS1 \
		-r ../../$READS2 \
		-o $FILEROOT.TF.fa \
		-t $THREADS \
		-v
	#remove intermediate folders containing large bam files
	if ls $FAFILE*transfuse* 1> /dev/null 2>&1; then
		rm $FAFILE*transfuse*
	fi
	if ls transrate*$FAFILE* 1> /dev/null 2>&1; then
		rm -r transrate*$FAFILE*
	fi
	if ls transrate_*$FILEROOT* 1> /dev/null 2>&1; then
		rm -r transrate_*$FILEROOT*
	fi

	echo -e "completed Transfuse filtering at $(date) for $INPUT"
	echo -e "completed Transfuse filtering at $(date) for $INPUT" >> ../../$REPFILE
}

#######################################
# 5. Detonate
detonating () {
	echo -e "##################"
	echo -e "##################" >> $REPFILE
	echo -e "started Detonate contig removal at $(date) for $INPUT"
	echo -e "started Detonate contig removal at $(date) for $INPUT" >> $REPFILE

	#check if param file exists, if it doesn't then create it using the contigs themselves
	if [[ -f "$DETPARAM" ]]; then
		echo -e "\tProvided parameter file found, using $DETPARAM"
		echo -e "\tProvided parameter file found, using $DETPARAM" >> $REPFILE
	else
		rsem-eval-estimate-transcript-length-distribution $INPUT $OUTDIR/05-detonate/param.txt
		DETPARAM="$OUTDIR/05-detonate/param.txt"
		echo -e "\tNo parameter file provided, created $DETPARAM using $INPUT sequences"
		echo -e "\tNo parameter file provided, created $DETPARAM using $INPUT sequences" >> $REPFILE
	fi

	echo -e "\tstarted Detonate contig removal at $(date) for $INPUT: rsem-eval-calculate-score"
	echo -e "\tstarted Detonate contig removal at $(date) for $INPUT: rsem-eval-calculate-score" >> $REPFILE
	rsem-eval-calculate-score --transcript-length-parameters $DETPARAM \
		--bowtie2 --time \
		-p $THREADS \
		--paired-end \
		$READS1 \
		$READS2 \
		$INPUT \
		$OUTDIR/05-detonate/$FILEROOT.det \
		$READLEN

	echo -e "\tstarted Detonate contig removal at $(date) for $INPUT: parsing output"
	echo -e "\tstarted Detonate contig removal at $(date) for $INPUT: parsing output" >> $REPFILE
	#individual contig scores are in: $SCRATCH/$OUTDIR/$FILEROOT.det.score.isoforms.results
	#keep positive scores, discard negative scores
	awk '$9>"0" {print $1}' $OUTDIR/05-detonate/$FILEROOT.det.score.isoforms.results > $OUTDIR/05-detonate/$FILEROOT.det.score.isoforms.results.out

	#the "." in the transfuse renamed contigs causes a grep problem
	sed -i 's/\./D/g' $OUTDIR/05-detonate/$FILEROOT.det.score.isoforms.results.out
	sed -i 's/\./D/g' $INPUT

	#get the original assembled sequence
	grepFA "$OUTDIR/05-detonate/$FILEROOT.det.score.isoforms.results.out" "$OUTDIR/05-detonate/$FILEROOT.detonate.fa"

	#final file cleanup
	rm -r $OUTDIR/05-detonate/*.stat

	echo -e "completed Detonate contig removal at $(date) for $INPUT"
	echo -e "completed Detonate contig removal at $(date) for $INPUT" >> $REPFILE
}

#######################################
# 6. Corset
corseting () {
	echo -e "##################"
	echo -e "##################" >> $REPFILE
	echo -e "started Corset isoform merge at $(date) for $INPUT: salmon index"
	echo -e "started Corset isoform merge at $(date) for $INPUT: salmon indexs" >> $REPFILE
	FILEROOT=$( echo $FILE | cut -d "." -f 1 )
	#create salmon index first, then salmon to align reads
	SALMONVER=$($SALMONDIR/salmon -v | cut -d" " -f2-)
	if [[ $SALMONVER != "" ]]; then
		echo -e "\trunning salmon version $SALMONVER ... proceeding"
		echo -e "\trunning salmon version $SALMONVER ... proceeding" >> $REPFILE
	else
		echo -e "\tyou may be running the out of date Salmon used by Transfuse ... attempting to proceed"
		echo -e "\tyou may be running the out of date Salmon used by Transfuse ... attempting to proceed" >> $REPFILE
	fi
	$SALMONDIR/salmon index -t $INPUT \
		-i $OUTDIR/06-corset/index \
		-k $SALMONK

		echo -e "\tread files found"
		echo -e "\tread files found" >> $REPFILE
		echo -e "\tCorset isoform merge at  $(date) for $INPUT: salmon quant"
		echo -e "\tstarted Corset isoform merge at $(date) for $INPUT: salmon quant" >> $REPFILE
	#salmon to align reads
	$SALMONDIR/salmon quant -i $OUTDIR/06-corset/index -l A \
		-1 $READS1 \
		-2 $READS2 \
		--validateMappings \
		--dumpEq \
		--writeOrphanLinks \
		-p $THREADS \
		-o $OUTDIR/06-corset/

	echo -e "\tCorset isoform merge at  $(date) for $INPUT: corset"
	echo -e "\tstarted Corset isoform merge at $(date) for $INPUT: corset" >> $REPFILE
	gunzip $OUTDIR/06-corset/aux_info/eq_classes.txt.gz
	corset -d $CORSETD \
		-p "$OUTDIR/06-corset/corset" \
		-i salmon_eq_classes \
		$OUTDIR/06-corset/aux_info/eq_classes.txt

	echo -e "\tCorset isoform merge at  $(date) for $INPUT: parse clusters"
	echo -e "\tstarted Corset isoform merge at $(date) for $INPUT: parse clusters" >> $REPFILE
	#convert the comma delimited list needed for Corset into the space delimited list needed here
	CORSETDL=$(echo $CORSETD | sed "s/,/ /g")
	for D in $CORSETDL; do
		join -1 1 -2 1 <(sort -k 1b,1 $OUTDIR/06-corset/corset-clusters-"$D".txt) <(sort -k 1b,1 $OUTDIR/06-corset/quant.sf) > $OUTDIR/06-corset/corset.$D.clusters.join
		awk '{ print $0, "\t", $6/$3 }' $OUTDIR/06-corset/corset.$D.clusters.join | sort -k7,7nr -k3,3nr | sort -u -k2,2 | sort -k7,7nr | cut -d" " -f1 | sort > $OUTDIR/06-corset/corset.$D.clusters.id
		grepFA "$OUTDIR/06-corset/corset.$D.clusters.id" $OUTDIR/06-corset/$FILEROOT.06.Corset.$D.fa
		echo -e "\t$(date) completed Corset d=$D completed"
		echo -e "\t$(date) completed Corset d=$D completed" >> $REPFILE
	done

	echo -e "completed Corset isoform merge at $(date) for $INPUT"
	echo -e "completed Corset isoform merge at $(date) for $INPUT" >> $REPFILE
}

#######################################
# 7. Describe contig sets
summarizing () {
	echo -e "##################"
	echo -e "##################" >> $REPFILE
	echo -e "started summaries at $(date) for *.fa in $OUTDIR/fasta-summaries"
	echo -e "started summaries at $(date) for *.fa in $OUTDIR/fasta-summaries" >> $REPFILE

	mkdir -p $OUTDIR/fasta-summaries/len
	mkdir -p $OUTDIR/fasta-summaries/tmp
	touch $OUTDIR/fasta-summaries/Mariner.summary.csv
	echo "fasta,number of contigs,L10,L25,L50,L75,L90,auL,number of bases,N10,N25,N50,N75,N90,auN,average contig length,median contig length,min contig length,max contig length,contigs <200 bp,contigs <500bp,contigs >1000 bp,contigs >10000 bp" >> $OUTDIR/fasta-summaries/Mariner.summary.csv

	for FASTA in $1/*fa; do

		local FAFILE=$(rev <<< "$FASTA" | cut -d "/" -f1 | rev)
		local file="$OUTDIR/fasta-summaries/len/$FAFILE.len.tsv"

		linearizeFA "$FASTA" "$OUTDIR/fasta-summaries/tmp/$FAFILE"

		lenCal "$OUTDIR/fasta-summaries/tmp/$FAFILE"
		mv $OUTDIR/fasta-summaries/tmp/$FAFILE.len.tsv $OUTDIR/fasta-summaries/len

		#no need to consume disk space, cleaning up as we go since it's just the length tsv file that is needed now
		rm "$OUTDIR/fasta-summaries/tmp/$FAFILE"

		# number of contigs
		NCONTIGS=$(wc -l $file | cut -d" " -f1)
		# number of bases
		NBASES=$(awk '{ sum += $2 } END { print sum }' $file)

		# N10,25,50,75,90; L10,25,50,75,90
		n=`echo $NBASES | awk '{print $1 * 10 / 100}'`
		#works, but fails for very large assemblies where it turns into a floating point situation
		#n=$(($NBASES * 10 / 100 ))
		#NVAL=0; c=0; while [ $NVAL -le $n ]; do read contig len; NVAL=$(($NVAL + $len)); c=$(($c + 1)); done < $file; N10=$len; L10=$c
		NVAL=0; c=0; while awk 'BEGIN {exit !('$NVAL' <= '$n')}'; do read contig len; NVAL=$(($NVAL + $len)); c=$(($c + 1)); done < $file; N10=$len; L10=$c


		#n=$(($NBASES * 25 / 100 ))
		n=`echo $NBASES | awk '{print $1 * 25 / 100}'`
		#NVAL=0; c=0; while [ $NVAL -le $n ]; do read contig len; NVAL=$(($NVAL + $len)); c=$(($c + 1)); done < $file; N25=$len; L25=$c
		NVAL=0; c=0; while awk 'BEGIN {exit !('$NVAL' <= '$n')}'; do read contig len; NVAL=$(($NVAL + $len)); c=$(($c + 1)); done < $file; N25=$len; L25=$c

		#n=$(($NBASES * 50 / 100 ))
		n=`echo $NBASES | awk '{print $1 * 50 / 100}'`
		VAL=0; c=0; while [ $NVAL -le $n ]; do read contig len; NVAL=$(($NVAL + $len)); c=$(($c + 1)); done < $file; N50=$len; L50=$c
		NVAL=0; c=0; while awk 'BEGIN {exit !('$NVAL' <= '$n')}'; do read contig len; NVAL=$(($NVAL + $len)); c=$(($c + 1)); done < $file; N50=$len; L50=$c

		#n=$(($NBASES * 75 / 100 ))
		n=`echo $NBASES | awk '{print $1 * 75 / 100}'`
		#NVAL=0; c=0; while [ $NVAL -le $n ]; do read contig len; NVAL=$(($NVAL + $len)); c=$(($c + 1)); done < $file; N75=$len; L75=$c
		NVAL=0; c=0; while awk 'BEGIN {exit !('$NVAL' <= '$n')}'; do read contig len; NVAL=$(($NVAL + $len)); c=$(($c + 1)); done < $file; N75=$len; L75=$c

		n=$(($NBASES * 90 / 100 ))
		n=`echo $NBASES | awk '{print $1 * 90 / 100}'`
		#NVAL=0; c=0; while [ $NVAL -le $n ]; do read contig len; NVAL=$(($NVAL + $len)); c=$(($c + 1)); done < $file; N90=$len; L90=$c
		NVAL=0; c=0; while awk 'BEGIN {exit !('$NVAL' <= '$n')}'; do read contig len; NVAL=$(($NVAL + $len)); c=$(($c + 1)); done < $file; N90=$len; L90=$c

		# auN=(length(contig_i)) x (length(contig_i) / length(totalAssembly)); summed for all contigs
		#area under Nx curve
		auN=$(awk -v LEN=$NBASES '{ AUN += $2 * $2 / LEN }  END { print AUN }' $file)
		#using the same idea, area under the Lx curve
		auL=$(awk -v LEN=$NBASES -v C=1 '{ AUL += C * $2 / LEN ; C+=1}  END { print AUL }' $file)
		# longest, shortest, median, average length
		CONTIGAVG=$(awk '{ sum += $2 } END { if (NR > 0) print sum / NR }' $file)
		# put the lengths from col2 in an array (0...n); find the midpoint (1...n+1); if n is even then average the 2 values; else n is odd then take middle value (-1 because array starting at 0)
		CONTIGMEDIAN=$(awk '{ median[i++]=$2; } END { mid=int((i+1)/2); if (mid < (i+1)/2) print (median[mid-1]+median[mid])/2; else print median[mid-1] }' $file)
		CONTIGMIN=$(head -n1 $file | awk '{ print $2 }')
		CONTIGMAX=$(tail -n1 $file | awk '{ print $2 }')
		# N<200, N<500, N>1,000, N<10,000
		NLT200=0
		NLT500=0
		NGT1000=0
		NGT10000=0
		NLT200=$(awk -v threshold=200 '{ if ($2 < threshold) c++ } END  {print c }' $file)
		NLT500=$(awk -v threshold=500 '{ if ($2 < threshold) c++ } END { print c }' $file)
		NGT1000=$(awk -v threshold=1000 '{ if ($2 > threshold) c++ } END { print c }' $file)
		NGT10000=$(awk -v threshold=10000 '{ if ($2 > threshold) c++ } END { print c }' $file)

		echo "$FASTA,$NCONTIGS,$L10,$L25,$L50,$L75,$L90,$auL,$NBASES,$N10,$N25,$N50,$N75,$N90,$auN,$CONTIGAVG,$CONTIGMEDIAN,$CONTIGMIN,$CONTIGMAX,$NLT200,$NLT500,$NGT1000,$NGT10000" >> $OUTDIR/fasta-summaries/Mariner.summary.csv
		echo -e "$(date): $NBASES bases \t in \t $FASTA"
		echo -e "$(date): $NBASES bases \t in \t $FASTA" >> $REPFILE
	done
	echo -e "completed short summaries at $(date): summaries written to $OUTDIR/fasta-summaries/Mariner.summary.csv"
	echo -e "completed short summaries at $(date): summaries written to $OUTDIR/fasta-summaries/Mariner.summary.csv" >> $REPFILE

	#write 0-100 csv files; splitting into separate loops so each runs as a set and could be set up to run with separate flags
	for FASTA in $1/*fa; do
		#write Nx and Lx stats in range of 1 ... 100 for each assembly in the loop above
		mkdir -p $OUTDIR/fasta-summaries/LxNx_0-100

		local FAFILE=$(rev <<< "$FASTA" | cut -d "/" -f1 | rev)
		touch $OUTDIR/fasta-summaries/LxNx_0-100/$FAFILE.LxNx.csv
		local file="$OUTDIR/fasta-summaries/len/$FAFILE.len.tsv"
		NBASES=$(awk '{ sum += $2 } END { print sum }' $file)

		NVAL=0
		c=0

		p=0
		NX=$( head -n1 $file | cut -f2)
		LX=0
		echo "$p,$LX,$NX" >> $OUTDIR/fasta-summaries/LxNx_0-100/$FAFILE.LxNx.csv
		for p in {1..99}; do
			if [[ $(jobs | grep -c "sextant") -ge $THREADS ]]; then
				wait -n
			fi

			{
				#this is the same as the one-liners above for N/L 10,25,50,75,90
				=$(($NBASES * $p / 100 ))
				n=`echo $NBASES $p | awk '{print $1 * $2 / 100}'`
				NVAL=0
				c=0
				#while [ $NVAL -le $n ]; do
				while awk 'BEGIN {exit !('$NVAL' <= '$n')}'; do
					read contig len
					NVAL=$(($NVAL + $len))
					c=$(($c + 1))
				done < $file
				NX=$len
				LX=$c
				echo "$p,$LX,$NX" >> $OUTDIR/fasta-summaries/LxNx_0-100/$FAFILE.LxNx.csv
			} &
		done
		wait

		p=100
		NX=$( tail -n1 $file | cut -f2)
		LX=$( wc -l $file | cut -d " " -f1)
		#echo "$p,$LX,$NX" >> $OUTDIR/fasta-summaries/LxNx_0-100/$FAFILE.LxNx.csv

		sort -k1,1n $OUTDIR/fasta-summaries/LxNx_0-100/$FAFILE.LxNx.csv > $OUTDIR/fasta-summaries/tmp/$FAFILE.LxNx.csv.tmp
		mv $OUTDIR/fasta-summaries/tmp/$FAFILE.LxNx.csv.tmp $OUTDIR/fasta-summaries/LxNx_0-100/$FAFILE.LxNx.csv
		rm $OUTDIR/fasta-summaries/tmp/$FAFILE.LxNx.csv.tmpp

		#add in the column headers
		sed -i '1 i x,Lx,Nx' $OUTDIR/fasta-summaries/LxNx_0-100/$FAFILE.LxNx.csv

		echo -n "."
		echo -n "." >> $REPFILE
	done
	wait
	echo -e "completed Lx, Nx (x in 0..100) at $(date): summaries written to $OUTDIR/fasta-summaries/LxNx_0-100"
	echo -e "completed Lx, Nx (x in 0..100) at $(date): summaries written to $OUTDIR/fasta-summaries/LxNx_0-100" >> $REPFILE

	#if -X is set (length of simulation or other reference assembly) then compute
	if  [[ $SUMMREFX != "" && $SUMMREFX >0 ]]; then

		mkdir -p $OUTDIR/fasta-summaries/LxNx_refX
		touch $OUTDIR/fasta-summaries/auLN_s.csv
		touch $OUTDIR/fasta-summaries/LxNx_refX/$FAFILE.LxNx_refX.csv

		echo "fasta,auN_s,auL_s,length of simulation assembly,length of fasta,max x (len_fa/len_sim*100)" >> $OUTDIR/fasta-summaries/auLN_s.csv

		for FASTA in $1/*fa; do
			local FAFILE=$(rev <<< "$FASTA" | cut -d "/" -f1 | rev)
			local file="$OUTDIR/fasta-summaries/len/$FAFILE.len.tsv"
			NBASES=$(awk '{ sum += $2 } END { print sum }' $file)

			#dropping off any decimal points to give largest whole integer
			#MAXP=$(( 100 * $NBASES / $SUMMREFX ))
			MAXP=`echo $NBASES $SUMMREFX | awk '{print 100 * $1 / $2 }'`
			#drop any decimal point; the awk math keeps the decimal points
			MAXPFLR=${MAXP%.*}
			#the last value will be the biggest value in the dataset; -1 to go up to that point only
			#MAXPMO=$(( $MAXP - 1 ))
			MAXPMO=`echo $MAXPFLR | awk '{print $1 - 1}'`

			p=0
			NX=$( head -n1 $file | cut -f2)
			LX=0
			echo "$p,$LX,$NX" >> $OUTDIR/fasta-summaries/LxNx_refX/$FAFILE.LxNx_refX.csv

			for p in $(eval echo "{1..$MAXPMO}"); do
				if [[ $(jobs | grep -c "sextant") -ge $THREADS ]]; then
					wait -n
				fi

				{
					#n=$(( $SUMMREFX * $p / 100 ))
					n=`echo $SUMMREFX $p | awk '{print $1 * $2 / 100}'`
					NVAL=0
					c=0
					#while [ $NVAL -le $n ]; do
					while awk 'BEGIN {exit !('$NVAL' <= '$n')}'; do
						read contig len
						NVAL=$(($NVAL + $len))
						c=$(($c + 1))
					done < $file
					NX=$len
					LX=$c
					echo "$p,$LX,$NX" >> $OUTDIR/fasta-summaries/LxNx_refX/$FAFILE.LxNx_refX.csv
				} &
			done
			wait

			p=$MAXPFLR
			NX=$( tail -n1 $file | cut -f2)
			LX=$( wc -l $file | cut -d " " -f1)
			echo "$p,$LX,$NX" >> $OUTDIR/fasta-summaries/LxNx_refX/$FAFILE.LxNx_refX.csv

			sort -k1,1n $OUTDIR/fasta-summaries/LxNx_refX/$FAFILE.LxNx_refX.csv > $OUTDIR/fasta-summaries/tmp/$FAFILE.LxNx_refX.csv.tmp
			mv $OUTDIR/fasta-summaries/tmp/$FAFILE.LxNx_refX.csv.tmp $OUTDIR/fasta-summaries/LxNx_refX/$FAFILE.LxNx_refX.csv
			rm $OUTDIR/fasta-summaries/tmp/$FAFILE.LxNx_refX.csv.tmp

			#add in the column headers
			sed -i '1 i x,Lx,Nx' $OUTDIR/fasta-summaries/LxNx_refX/$FAFILE.LxNx_refX.csv

			#using the length of the simulation (or other) reference assembly allows for the area under the curves to be compared across methods and assemblies
			auNs=$(awk -v LEN=$SUMMREFX '{ AUN += $2 * $2 / LEN }  END { print AUN }' $file)
			auLs=$(awk -v LEN=$SUMMREFX -v C=1 '{ AUL += C * $2 / LEN ; C+=1}  END { print AUL }' $file)
			echo -e "$(date): auN_s = $auNs \t auL_s = $auLs \t for x in range 1..$MAXPFLR for $FAFILE"
			echo -e "$(date): auN_s = $auNs \t auL_s = $auLs \t for x in range 1..$MAXPFLR for $FAFILE" >> $REPFILE
			echo "$FAFILE,$auNs,$auLs,$SUMMREFX,$NBASES,$MAXPFLR" >> $OUTDIR/fasta-summaries/auLN_s.csv
		done
		wait

		echo -e "completed Lx, Nx with reference at $(date): summaries written to $OUTDIR/fasta-summaries/Mariner.summary.csv"
		echo -e "completed Lx, Nx with reference at $(date): summaries written to $OUTDIR/fasta-summaries/Mariner.summary.csv" >> $REPFILE
	fi
}

#######################################
#	RUN MARINER                       #
#######################################
#	lin.fa is used to grep sequences from if necessary
WD=$(pwd)
#if no prior analysis run, then INPUT is from the command line option
#	if a prior analysis has been run, then INPUT was set by that parameter below
PRIORANALYSIS=0
mkdir -p $OUTDIR/output
# for each program selected:
#	check all params are defined,
#	run the function,
#	check the expected output exists,
#	set the input for a possible next step
if [[ $CONSENSUS == "TRUE" ]]; then
	parseInput
	INPUT="$OUTDIR/input/$FILEROOT.lin.fa"
	mkdir -p $OUTDIR/01-consensus
	#run consensus
	consensual
	PRIORANALYSIS=1
	cp $OUTDIR/01-consensus/$FILEROOT.consensus2.tr.fa $OUTDIR/output/$FILEROOT.01.consensus2.tr.fa
	cp $OUTDIR/01-consensus/$FILEROOT.consensus3.tr.fa $OUTDIR/output/$FILEROOT.01.consensus3.tr.fa
	cp $OUTDIR/01-consensus/$FILEROOT.consensus4.tr.fa $OUTDIR/output/$FILEROOT.01.consensus4.tr.fa
	cp $OUTDIR/01-consensus/$FILEROOT.consensus5.tr.fa $OUTDIR/output/$FILEROOT.01.consensus5.tr.fa
	INPUT="$OUTDIR/output/$FILEROOT.01.consensus2.fa"
fi
if [[ $EVIGENE == "TRUE" ]]; then
	parseInput
	if [[ $PRIORANALYSIS == 0 ]]; then
		INPUT="$OUTDIR/input/$FILEROOT.lin.fa"
	fi
	mkdir -p $OUTDIR/02-evigene
	cp $INPUT $OUTDIR/02-evigene
	cd $OUTDIR/02-evigene
	#run evigene & antifam
	evidencing
	#cd back to original working directory
	cd $WD
	PRIORANALYSIS=1
	cp $OUTDIR/02-evigene/$FAFILE.evi4Full.tr $OUTDIR/output/$FILEROOT.02a.evi4full.tr.fa
	cp $OUTDIR/02-evigene/AntiFam/$FAFILE.AF.tr.fa $OUTDIR/output/$FAFILE.02b.evi4full.AF.tr.fa
	INPUT="$OUTDIR/output/$FAFILE.02b.evi4full.AF.tr.fa"
fi
if [[ $TPM == "TRUE" ]]; then
	parseInput
	if [[ $PRIORANALYSIS == 0 ]]; then
		INPUT="$OUTDIR/input/$FILEROOT.lin.fa"
	fi
	mkdir -p $OUTDIR/03-TPMfiltering
	filtering
	PRIORANALYSIS=1
	cp $OUTDIR/03-TPMfiltering/$FILEROOT.tpm0.fa $OUTDIR/output/$FAFILE.03.tpm0.fa
	INPUT="$OUTDIR/output/$FAFILE.03.tpm0.fa"
fi
if [[ $TRANSFUSE == "TRUE" ]]; then
	parseInput
	#check that the read files exist
	checkReads
	echo -e "\tread files found"
	echo -e "\tread files found" >> $REPFILE
	#use whatever INPUT is, either set above if not the first step or original input as a possible list of fastas
	mkdir -p $OUTDIR/04-transfuse
	cd $OUTDIR/04-transfuse
	transfusing
	PRIORANALYSIS=1
	cd $WD

	#check that Transfuse output is present
	if ls $OUTDIR/04-transfuse/Transfuse/*/$FILEROOT.TF.fa 1> /dev/null 2>&1 || ls $OUTDIR/04-transfuse/$FILEROOT.TF.fa 1> /dev/null 2>&1; then
		if ls $OUTDIR/04-transfuse/Transfuse/*/$FILEROOT.TF.fa 1> /dev/null 2>&1; then
			cp $OUTDIR/04-transfuse/Transfuse/*/$FILEROOT.TF.fa $OUTDIR/output/$FILEROOT.04c.TF3.fa
			cp $OUTDIR/04-transfuse/Transfuse/*/$FILEROOT.TF_cons.fa $OUTDIR/output/$FILEROOT.04b.TF2.fa
			cp $OUTDIR/04-transfuse/Transfuse/*/$FILEROOT*_filtered.fa $OUTDIR/output/$FILEROOT.04a.TF1.fa
		else
			cp $OUTDIR/04-transfuse/$FILEROOT.TF.fa $OUTDIR/output/$FILEROOT.04c.TF3.fa
			cp $OUTDIR/04-transfuse/$FILEROOT.TF_cons.fa $OUTDIR/output/$FILEROOT.04b.TF2.fa
			cp $OUTDIR/04-transfuse/$FILEROOT*_filtered.fa $OUTDIR/output/$FILEROOT.04a.TF1.fa
		fi
		INPUT="$OUTDIR/output/$FILEROOT.04c.TF3.fa"
		#all 3 output files found
		echo -e "Output written for all 3 stages of Transfuse"
		echo -e "Output written for all 3 stages of Transfuse" >> $REPFILE
	elif ls $OUTDIR/04-transfuse/Transfuse/*/$FILEROOT.TF_cons.fa 1> /dev/null 2>&1 || ls $OUTDIR/04-transfuse/$FILEROOT.TF_cons.fa 1> /dev/null 2>&1; then
		if ls $OUTDIR/04-transfuse/Transfuse/*/$FILEROOT.TF_cons.fa 1> /dev/null 2>&1; then
			cp $OUTDIR/04-transfuse/Transfuse/*/$FILEROOT.TF_cons.fa $OUTDIR/output/$FILEROOT.04b.TF2.fa
			cp $OUTDIR/04-transfuse/Transfuse/*/$FILEROOT.*_filtered.fa $OUTDIR/output/$FILEROOT.04a.TF1.fa
		else
			cp $OUTDIR/04-transfuse/$FILEROOT.TF_cons.fa $OUTDIR/output/$FILEROOT.04b.TF2.fa
			cp $OUTDIR/04-transfuse/$FILEROOT.*_filtered.fa $OUTDIR/output/$FILEROOT.04a.TF1.fa
		fi
		INPUT="$OUTDIR/output/$FILEROOT.04b.TF2.fa"
		#TF3 failed
		echo -e "Transfuse final Transrate failed, using vsearch output as INPUT if subsequent Mariner steps requested\nThis may be appropriate to do if a single file was used as input to Transfuse; if multiple files were used as input then consider filtering transcripts with tpm=0 or using evigene prior to running Transfuse. Running Transfuse implementation of Transrate without Salmon error models may also resolve the problem."
		echo -e "Transfuse final Transrate failed, using vsearch output as INPUT if subsequent Mariner steps requested\nThis may be appropriate to do if a single file was used as input to Transfuse; if multiple files were used as input then consider filtering transcripts with tpm=0 or using evigene prior to running Transfuse. Running Transfuse implementation of Transrate without Salmon error models may also resolve the problem." >> $REPFILE
	elif ls "$OUTDIR/04-transfuse/Transfuse/*/$FILEROOT""_filtered.fa" 1> /dev/null 2>&1 || ls "$OUTDIR/04-transfuse/Transfuse/$FILEROOT""_filtered.fa" 1> /dev/null 2>&1; then
		#TF2 failed
		echo -e "Transfuse vsearch failed, check that the initial Transrate filtering stage of Transfuse completed correctly."
		echo -e "Transfuse vsearch failed, check that the initial Transrate filtering stage of Transfuse completed correctly." >> $REPFILE
		kill -INT $$
	else
		#TF1 (transrate) failed
		echo -e "Transfuse failed with the initial Transrate filtering stage. Running the Transfuse implementation of Transrate without Salmon error models may resolve the problem, otherwise consider filtering  contigs to remove those with tpm=0 and/or filter using evigene, and then try running Transfuse again.\nIf Transfuse continues to fail at this initial stage, consider using the TPM expression filtering output as input to Detonate."
		echo -e "Transfuse failed with the initial Transrate filtering stage. Running the Transfuse implementation of Transrate without Salmon error models may resolve the problem, otherwise consider filtering  contigs to remove those with tpm=0 and/or filter using evigene, and then try running Transfuse again.\nIf Transfuse continues to fail at this initial stage, consider using the TPM expression filtering output as input to Detonate." >> $REPFILE
		kill -INT $$
	fi
fi
if [[ $DETONATE == "TRUE" ]]; then
	parseInput
	if [[ $PRIORANALYSIS == 0 ]]; then
		INPUT="$OUTDIR/input/$FILEROOT.lin.fa"
	fi
	#check that the read files exist
	checkReads
	echo -e "\tread files found"
	echo -e "\tread files found" >> $REPFILE

	mkdir -p $OUTDIR/05-detonate
	detonating
	PRIORANALYSIS=1
	cp $OUTDIR/05-detonate/$FILEROOT.detonate.fa $OUTDIR/output/$FILEROOT.05.Detonate.fa
	INPUT="$OUTDIR/output/$FILEROOT.05.Detonate.fa"
fi
if [[ $CORSET == "TRUE" ]]; then
	parseInput
	if [[ $PRIORANALYSIS == 0 ]]; then
		INPUT="$OUTDIR/input/$FILEROOT.lin.fa"
	fi
	#check that the read files exist
	checkReads
	echo -e "\tread files found"
	echo -e "\tread files found" >> $REPFILE

	mkdir -p $OUTDIR/06-corset
	corseting
	PRIORANALYSIS=1
	cp $OUTDIR/06-corset/$FILEROOT.06.Corset.*.fa $OUTDIR/output
fi
if [[ $SUMMARY == "TRUE" ]]; then
	mkdir -p $OUTDIR/fasta-summaries
	if [[ $PRIORANALYSIS == 1 ]]; then
		SUMMARYDIR="$OUTDIR/output"
	else
		SUMMARYDIR="$INPUT"
	fi
	#run summaries and write to output file and to csv
	summarizing "$SUMMARYDIR"
fi

echo -e "##################"
echo -e "##################" >> $REPFILE
echo -e "Mariner completed: $(date)"
echo -e "Mariner completed: $(date)" >> $REPFILE
echo -e "##################"
echo -e "##################" >> $REPFILE
#######################################
#            MARINERS' END            #
#######################################
