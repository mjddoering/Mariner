#download base image ubuntu 20.04
# sudo docker build -t mariner:0.2b ./
FROM ubuntu:20.04
LABEL maintainer="umdoeri0@myumanitoba.ca"
LABEL maintainer="MJD Doering"
LABEL version="0.2b"
LABEL description="This is installation of de novo transcriptome assemblers and their dependencies \
        * IDBA-Tran \
        * rnaSPAdes \
        * SOAPdenovo-Trans && GapCloser \
        TransABySS cannot get it to install without errors, missing abyss files somehow\
        * TransLiG \
        * Trinity \
         \
        this also installs \
        FastQC \
        Atropos \
        Trimmomatic \
        sortMeRNA and rRNA databases \
        BBTools \
        firmament script to standardize contig names and remove short contigs"
ENV DEBIAN_FRONTEND teletype
RUN apt-get update && apt-get install -y --no-install-recommends apt-utils \
        bowtie2 \
        cmake \
        default-jre \
        g++ \
        gcc \
        git \
        jellyfish \
        libbz2-dev \
        make \
        parallel \
        pigz \
        python3-setuptools \
        python3-pip \
        python \
        ruby-full \
        samtools \
        tmux \
        wget \
        vim \
        zlib1g-dev

RUN pip3 install numpy scipy

RUN useradd -ms /bin/bash vega

USER root
WORKDIR /home/mariner/software
ENV INSTALLPATH /home/mariner/software

###     install IDBA                    ###
RUN cd $INSTALLPATH && \
        wget https://github.com/loneknightpy/idba/releases/download/1.1.3/idba-1.1.3.tar.gz && \
        tar -zxvf idba-1.1.3.tar.gz && rm -f idba-1.1.3.tar.gz
RUN cd $INSTALLPATH/idba-1.1.3 && \
        sed -i "s/kMaxShortSequence = 128/kMaxShortSequence = 250/" src/sequence/short_sequence.h && \
        sed -i "s/kNumUint64 = 4/kNumUint64 = 16/" src/basic/kmer.h && \
        ./configure && \
        make
ENV PATH $INSTALLPATH/idba-1.1.3/bin:$PATH

###     install rnaSPAdes               ###
RUN cd $INSTALLPATH && \
        wget --no-check-certificate http://cab.spbu.ru/files/release3.14.1/SPAdes-3.14.1-Linux.tar.gz && \
        tar -zxvf SPAdes-3.14.1-Linux.tar.gz && rm -f SPAdes-3.14.1-Linux.tar.gz
ENV PATH $INSTALLPATH/SPAdes-3.14.1-Linux/bin:$PATH

###     install Salmon                  ###
RUN cd $INSTALLPATH && \
        wget --no-check-certificate https://github.com/COMBINE-lab/salmon/releases/download/v1.3.0/salmon-1.3.0_linux_x86_64.tar.gz && \
        tar -zxvf salmon-1.3.0_linux_x86_64.tar.gz && rm -f salmon-1.3.0_linux_x86_64.tar.gz
ENV PATH $INSTALLPATH/salmon-latest_linux_x86_64/bin:$PATH

###     install SOAPdenovo-Trans        ###
RUN cd $INSTALLPATH && \
        wget --no-check-certificate https://github.com/aquaskyline/SOAPdenovo-Trans/archive/1.0.4.tar.gz && \
        tar -zxvf 1.0.4.tar.gz && rm -f 1.0.4.tar.gz
RUN cd SOAPdenovo-Trans-1.0.4 && \
        sh make.sh
ENV PATH $INSTALLPATH/SOAPdenovo-Trans-1.0.4:$PATH

###     install GapCloser               ###
RUN cd $INSTALLPATH && \
        mkdir GapCloser && cd GapCloser && \
        wget --no-check-certificate https://sourceforge.net/projects/soapdenovo2/files/GapCloser/bin/r6/GapCloser-bin-v1.12-r6.tgz && \
        tar -zxvf GapCloser-bin-v1.12-r6.tgz
ENV PATH $INSTALLPATH/GapCloser:$PATH

###     install TransLiG                ###
RUN apt-get install -y build-essential g++ python-dev autotools-dev libicu-dev build-essential libbz2-dev libboost-dev libboost-all-dev
RUN cd $INSTALLPATH && \
        wget https://dl.bintray.com/boostorg/release/1.69.0/source/boost_1_69_0.tar.gz && \
        tar -zxvf boost_1_69_0.tar.gz && rm -r boost_1_69_0.tar.gz
RUN cd boost_1_69_0
CMD ["bootstrap.sh"]
CMD ["b2"]
ENV LD_LIBRARY_PATH $INSTALLPATH/boost_1_69_0/lib:$LD_LIBRARY_PATH
RUN cd $INSTALLPATH && \
        wget https://sourceforge.net/projects/transcriptomeassembly/files/TransLiG/TransLiG_1.3.tar.gz && \
        tar -zxvf TransLiG_1.3.tar.gz && rm -r TransLiG_1.3.tar.gz
RUN cd $INSTALLPATH/TransLiG_1.3
RUN cd $INSTALLPATH/TransLiG_1.3 && ./configure --with-boost=$INSTALLPATH/boost_1_69_0
RUN cd $INSTALLPATH/TransLiG_1.3 && make
ENV PATH $INSTALLPATH/TransLiG_1.3:$PATH

###     install Trinity                 ###
RUN cd $INSTALLPATH && \
        wget https://github.com/trinityrnaseq/trinityrnaseq/releases/download/v2.11.0/trinityrnaseq-v2.11.0.FULL.tar.gz && \
        tar -zxvf trinityrnaseq-v2.11.0.FULL.tar.gz && rm -f trinityrnaseq-v2.11.0.FULL.tar.gz && \
        cd trinityrnaseq-v2.11.0 && \
        make && make plugins
ENV PATH $INSTALLPATH/trinityrnaseq-v2.11.0:$PATH
ENV TRINITY_HOME $INSTALLPATH/trinityrnaseq-v2.11.0/

###     install FastQC                  ###
RUN apt-get -y install unzip default-jre
RUN cd $INSTALLPATH && \
        wget https://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v0.11.9.zip && \
        unzip fastqc_v0.11.9.zip && rm -f fastqc_v0.11.9.zip && \
        chmod +x $INSTALLPATH/FastQC/fastqc
ENV PATH $INSTALLPATH/FastQC:$PATH

###     install Atropos                 ###
RUN pip3 install atropos

###     install Trimmomatic             ###
RUN cd $INSTALLPATH && \
        wget http://www.usadellab.org/cms/uploads/supplementary/Trimmomatic/Trimmomatic-0.39.zip && \
        unzip Trimmomatic-0.39.zip && rm -f Trimmomatic-0.39.zip
ENV PATH $INSTALLPATH/Trimmomatic-0.39:$PATH

###     install sortMeRNA               ###
RUN cd $INSTALLPATH && \
        wget https://github.com/biocore/sortmerna/releases/download/v4.2.0/sortmerna-4.2.0-Linux.tar.gz && \
        tar -zxvf sortmerna-4.2.0-Linux.tar.gz && rm -f sortmerna-4.2.0-Linux.tar.gz
ENV PATH $INSTALLPATH/sortmerna-4.2.0-Linux/bin:$PATH
RUN cd $INSTALLPATH/sortmerna-4.2.0-Linux && \
        wget https://github.com/biocore/sortmerna/archive/master.zip && \
        unzip master.zip && \
        cp sortmerna-master/data/rRNA_databases/*fasta ./ && \
        rm -r sortmerna-master && \
        rm -r master.zip && \
        cat [rs]*fasta > fullRefSortMe.fa

###     install BBTools                 ###
RUN cd $INSTALLPATH && \
        wget https://sourceforge.net/projects/bbmap/files/BBMap_38.86.tar.gz && \
        tar -zxvf BBMap_38.86.tar.gz && rm -f BBMap_38.86.tar.gz
ENV PATH $INSTALLPATH/bbmap:$PATH

###     install Evidential Gene         ###
RUN cd $INSTALLPATH && \
        wget http://arthropods.eugenes.org/EvidentialGene/other/evigene_old/evigene_older/evigene20may20.tar && \
        tar -xvf evigene20may20.tar && rm -f evigene20may20.tar && \
        sed -i "s/\$s= \$sdef;/\$sdef=~s\/[0-9].*$\/\/; \n\t \$s= \$sdef;/" evigene/scripts/prot/tr2aacds4.pl
ENV PATH $INSTALLPATH/evigene:$PATH
ENV PATH $INSTALLPATH/evigene/scripts:$PATH
ENV PATH $INSTALLPATH/evigene/scripts/prot:$PATH
ENV PATH $INSTALLPATH/evigene/scripts/prot:$PATH
ENV PATH $INSTALLPATH/evigene/scripts/rnaseq:$PATH
RUN cd $INSTALLPATH && \
        wget http://ftp.ebi.ac.uk/pub/software/vertebrategenomics/exonerate/exonerate-2.2.0-x86_64.tar.gz && \
        tar -zxvf exonerate-2.2.0-x86_64.tar.gz && rm -f exonerate-2.2.0-x86_64.tar.gz`
ENV PATH $INSTALLPATH/exonerate-2.2.0-x86_64/bin

###     install hmmer & Antifam db      ###
RUN cd $INSTALLPATH && \
        wget http://eddylab.org/software/hmmer/hmmer.tar.gz && \
        tar -zxvf hmmer.tar.gz && rm -f hmmer.tar.gz  && \
        cd hmmer-3.3.1 && ./configure --prefix $INSTALLPATH/hmmer-3.3.1 && \
        make && make install
ENV PATH $INSTALLPATH/hmmer-3.3.1/src:$PATH
RUN cd $INSTALLPATH && \
        wget ftp://ftp.ebi.ac.uk/pub/databases/Pfam/AntiFam/AntiFam_6.0.tar.gz && \
        tar -zxvf AntiFam_6.0.tar.gz && rm -f AntiFam_6.0.tar.gz && \
        mkdir AntiFam_6.0 && mv AntiFam*seed AntiFam_6.0 && mv AntiFam*hmm AntiFam_6.0 && \
        mv relnotes AntiFam_6.0 && mv version AntiFam_6.0

###     install Transfuse               ###
RUN cd $INSTALLPATH && \
        wget https://github.com/cboursnell/transfuse/archive/v0.5.0.tar.gz && \
        tar -zxvf v0.5.0.tar.gz && rm -f v0.5.0.tar.gz && \
        cd transfuse-0.5.0 && \
        gem build *spec && gem install *gem
RUN cd $INSTALLPATH && \
        wget https://github.com/COMBINE-lab/salmon/releases/download/v0.4.0/SalmonBeta-0.4.0_Ubuntu-14.04.tar.gz && \
        tar -zxvf SalmonBeta-0.4.0_Ubuntu-14.04.tar.gz && rm -f SalmonBeta-0.4.0_Ubuntu-14.04.tar.gz
ENV PATH $INSTALLPATH/SalmonBeta-0.4.0_Ubuntu-14.04.tar.gz/bin:$PATH
RUN cd $INSTALLPATH && \
        wget https://github.com/torognes/vsearch/archive/v1.8.0.tar.gz && \
        tar -zxvf v1.8.0.tar.gz && rm -f v1.8.0.tar.gz && \
        cd vsearch-1.8.0 && ./autogen.sh && ./configure && \
        make
ENV PATH $INSTALLPATH/vsearch-1.8.0:$PATH
ENV PATH $INSTALLPATH/vsearch-1.8.0/bin:$PATH
RUN cd $INSTALLPATH && \
        wget https://github.com/amplab/snap/releases/download/v1.0beta.18/snap-aligner && \
        mkdir snap-1.0beta.18 && mv snap-aligner snap-1.0beta.18
ENV PATH $INSTALLPATH/snap-1.0beta.18:$PATH

###     install Detonate                ###
RUN cd $INSTALLPATH && \
        wget http://deweylab.biostat.wisc.edu/detonate/detonate-1.11-precompiled.tar.gz && \
        tar -zxvf detonate-1.11-precompiled.tar.gz && rm -r detonate-1.11-precompiled.tar.gz && \
        mv detonate-1.11-precompiled detonate-1.11
ENV PATH $INSTALLPATH/detonate-1.11/rsem-eval:$PATH
ENV PATH $INSTALLPATH/detonate-1.11/ref-eval:$PATH

###     install rnaQUAST                ###
RUN pip3 install biopython gffutils matplotlib joblib
RUN cd $INSTALLPATH && \
        wget http://research-pub.gene.com/gmap/src/gmap-gsnap-2020-10-14.tar.gz && \
        tar -zxvf gmap-gsnap-2020-10-14.tar.gz && rm -r gmap-gsnap-2020-10-14.tar.gz && \
        cd gmap-2020-10-14 && ./configure && \
        make && make install
RUN cd $INSTALLPATH && \
        wget https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/ncbi-blast-2.10.1+-x64-linux.tar.gz && \
        tar -zxvf ncbi-blast-2.10.1+-x64-linux.tar.gz && rm -f ncbi-blast-2.10.1+-x64-linux.tar.gz
ENV PATH $INSTALLPATH/ncbi-blast-2.10.1+/bin:$PATH
RUN cd $INSTALLPATH && \
        wget ftp://emboss.open-bio.org/pub/EMBOSS/EMBOSS-6.6.0.tar.gz && \
        tar -zxvf EMBOSS-6.6.0.tar.gz && rm -f EMBOSS-6.6.0.tar.gz && \
        cd EMBOSS-6.6.0 && ./configure --without-x && make
ENV PATH $INSTALLPATH/EMBOSS-6.6.0/emboss:$PATH

###     install BUSCO                   ###
        #get dependencies first
RUN apt-get install -y perl \
        libboost-iostreams-dev \
        libgsl-dev \
        libsuitesparse-dev \
        liblpsolve55-dev \
        libsqlite3-dev \
        libmysql++-dev \
        libbamtools-dev \
        liblzma-dev \
        libcurl4-openssl-dev \
        xz-utils \
        libncurses5-dev
RUN cd $INSTALLPATH && \
        wget https://github.com/samtools/htslib/releases/download/1.11/htslib-1.11.tar.bz2 && \
        tar -vxjf htslib-1.11.tar.bz2 && rm -f htslib-1.11.tar.bz2 && \
        cd htslib-1.11 && autoheader && autoconf && ./configure && make && make install
ENV PATH $INSTALLPATH/htslib-1.11:$PATH
RUN cd $INSTALLPATH && \
        wget https://github.com/samtools/bcftools/releases/download/1.11/bcftools-1.11.tar.bz2 && \
        tar -vxjf bcftools-1.11.tar.bz2 && rm -f bcftools-1.11.tar.bz2 && \
        cd bcftools-1.11/ && autoheader && autoconf && ./configure && make && make install
ENV PATH $INSTALLPATH/bcftools-1.11:$PATH
RUN cd $INSTALLPATH && \
        wget https://github.com/samtools/samtools/releases/download/1.11/samtools-1.11.tar.bz2 && \
        tar -vxjf samtools-1.11.tar.bz2 && rm -f samtools-1.11.tar.bz2 && \
        cd samtools-1.11/ && autoheader && autoconf -Wno-syntax && ./configure && make && make install
RUN cd $INSTALLPATH && \
        export TOOLDIR=$INSTALLPATH

### R
RUN apt-get install -y dirmngr gnupg apt-transport-https ca-certificates software-properties-common r-base r-base-core r-recommended
RUN R -e install.packages digest gtable lazyeval plyr reshape2 rlang scales tibble viridisLite withr
RUN R -e install.packages ggplot2

###     install STAR aligner            ###
RUN cd $INSTALLPATH && \
        wget https://github.com/alexdobin/STAR/archive/2.7.6a.tar.gz && \
        tar -zxvf 2.7.6a.tar.gz && rm -f 2.7.6a.tar.gz
ENV PATH $INSTALLPATH/STAR-2.7.6a/bin/Linux_x86_64:$PATH

RUN cd $INSTALLPATH && \
        wget https://github.com/Gaius-Augustus/Augustus/archive/v3.3.3.tar.gz && \
        tar -zxvf v3.3.3.tar.gz && rm -f v3.3.3.tar.gz && \
        sed -i "/bam2wig/d" Augustus-3.3.3/auxprogs/Makefile && \
        cd Augustus-3.3.3 && make
ENV PATH $INSTALLPATH/Augustus-3.3.3/bin:$PATH
ENV PATH $INSTALLPATH/Augustus-3.3.3/scripts:$PATH

RUN cd $INSTALLPATH && \
        wget https://github.com/soedinglab/metaeuk/archive/3-8dc7e0b.tar.gz && \
        tar -zxvf 3-8dc7e0b.tar.gz && rm -f 3-8dc7e0b.tar.gz && \
        cd metaeuk-3-8dc7e0b/ && mkdir -p build && \
        cd build && cmake -DCMAKE_BUILD_TYPE=Release -DHAVE_MPI=1 -DCMAKE_INSTALL_PREFIX=. .. && \
        make -j && make install
ENV PATH $INSTALLPATH/metaeuk-3-8dc7e0b/build/bin:$PATH
RUN cd $INSTALLPATH && \
        wget https://github.com/hyattpd/Prodigal/archive/v2.6.3.tar.gz && \
        tar -zxvf v2.6.3.tar.gz && rm -f v2.6.3.tar.gz && \
        cd Prodigal-2.6.3/ && make
ENV PATH $INSTALLPATH/Prodigal-2.6.3:$PATH
RUN apt-get install -y openjdk-11-jdk
RUN cd $INSTALLPATH && \
        wget https://github.com/smirarab/sepp/archive/4.3.10.tar.gz && \
        tar -zxvf 4.3.10.tar.gz && rm -f 4.3.10.tar.gz && \
        cd sepp-4.3.10 && \
        python3 setup.py config -c && \
        python3 setup.py config -c && chmod 777 run_sepp.py
ENV PATH $INSTALLPATH/sepp-4.3.10:$PATH
### R
RUN apt-get install -y dirmngr gnupg apt-transport-https ca-certificates software-properties-common r-base r-base-core r-recommended
RUN R -e install.packages digest gtable lazyeval plyr reshape2 rlang scales tibble viridisLite withr
RUN R -e install.packages ggplot2

RUN cd $INSTALLPATH && \
        wget https://gitlab.com/ezlab/busco/-/archive/4.1.4/busco-4.1.4.tar.gz && \
        tar -zxvf busco-4.1.4.tar.gz && rm -f busco-4.1.4.tar.gz && \
        cd busco-4.1.4/ && python3 setup.py install && \
        ./scripts/busco_configurator.py config/config.ini config/marinerConfig.ini && \
        export BUSCO_CONFIG_FILE="$INSTALLPATH/busco-4.1.4/config/marinerConfig.ini"
ENV PATH $INSTALLPATH/busco-4.1.4/bin:$PATH
ENV PATH $INSTALLPATH/busco-4.1.4/scripts:$PATH
ENV PATH $INSTALLPATH/busco-4.1.4/src:$PATH
ENV PATH $INSTALLPATH/busco-4.1.4/src/busco:$PATH

###     install cd-hit                  ###
RUN cd $INSTALLPATH && \
        wget https://github.com/weizhongli/cdhit/archive/V4.8.1.tar.gz && \
        tar -zxvf V4.8.1.tar.gz && rm -f V4.8.1.tar.gz && \
        cd cdhit-4.8.1 && \
        make && \
        cd cd-hit-auxtools && make
ENV PATH $INSTALLPATH/cdhit-4.8.1:$PATH
ENV PATH $INSTALLPATH/cdhit-4.8.1/cd-hit-auxtools:$PATH
###     install rnaQUAST                ###
#         installing it via conda instead,
#         leaving above dependencies to use separately from rnaQUAST
#RUN cd $INSTALLPATH && \
        #wget http://cab.spbu.ru/files/rnaquast/release2.1.0/rnaQUAST-2.1.0.tar.gz && \
        #tar -zxvf rnaQUAST-2.1.0.tar.gz && rm -f rnaQUAST-2.1.0.tar.gz && \
        #cd rnaQUAST-2.1.0
#ENV PATH $INSTALLPATH/rnaQUAST-2.1.0:$PATH
#RUN python3 rnaQUAST-2.1.0.py --test
RUN cd $INSTALLPATH && \
        wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
        bash Miniconda3-latest-Linux-x86_64.sh -b -p $INSTALLPATH/miniconda && \
        rm Miniconda3-latest-Linux-x86_64.sh
ENV PATH $INSTALLPATH/miniconda/bin:$PATH
RUN conda update conda -y && \
        conda config --add channels defaults && \
        conda config --add channels bioconda && \
        conda config --add channels conda-forge && \
        conda install -c bioconda rnaquast && \
        conda create -y --name rnaquast python=3 matplotlib joblib biopython gffutils rnaquast && \
        conda init bash
#conda activate rnaquast
#conda deactivate
#python software/miniconda/pkgs/rnaquast-2.1.0-1/bin/rnaQUAST.py --test

###     install firmament scripts       ###
RUN cd $INSTALLPATH && \
        wget https://github.com/mjddoering/Mariner/archive/v0.2.tar.gz && \
        tar -zxvf v0.2.tar.gz && rm -f v0.2.tar.gz && \
        chmod 777 Mariner-0.2/firmament/*.sh && \
        chmod 777 Mariner-0.2/sextant/*.sh
ENV PATH $INSTALLPATH/Mariner-0.2:$PATH
ENV PATH $INSTALLPATH/Mariner-0.2/firmament:$PATH
ENV PATH $INSTALLPATH/Mariner-0.2/sextant:$PATH
WORKDIR /home/mariner
#USER vega 
