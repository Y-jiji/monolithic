START=2000000
END=2000100
DATADIR=/media/gtnetuser/HDD_16TB_ATLAS/ethereum/data
DUMPDIR=/media/gtnetuser/HDD_16TB_ATLAS/ethereum/dump
mkdir -p $DATADIR
mkdir -p $DUMPDIR

for BLOCK in $(seq $START $END); do
    echo "DUMP BLOCK $BLOCK"
    geth --datadir $DATADIR dump $BLOCK > $DUMPDIR/eth-${BLOCK}.jsona 2> /dev/null
    echo ":: SIZE $(wc -l $DUMPDIR/eth-${BLOCK}.jsona)"
done
