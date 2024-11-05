# to peek running logs: tail -f <file name>
MYPATH=/media/gtnetuser/SSD_2TB_BEST/ethereum

# setup working dir
mkdir -p ${MYPATH}
cd ${MYPATH}

# kill running processes
kill -9 $(pgrep geth)
kill -9 $(pgrep prysm)
kill -9 $(pgrep beacon)

# download prysm client
curl https://raw.githubusercontent.com/prysmaticlabs/prysm/master/prysm.sh --output prysm.sh && chmod +x prysm.sh

# clear log and data
rm -rf ethersync-client.log
rm -rf ethersync-beacon.log
rm -rf data
mkdir -p ${MYPATH}/data/geth
mkdir -p ${MYPATH}/data/beacon

# create jwt secret
echo "2b4956f3c2dc15052da675bb58082b07698952bf3130ba99ad9c1fe2ca257e10" \
	> ${MYPATH}/jwtsecret

# run geth process
nohup geth --mainnet \
	--syncmode snap \
	--gcmode archive \
	--datadir ${MYPATH}/data/geth \
	--http --authrpc.addr localhost \
	--state.scheme="hash" \
	--authrpc.vhosts=localhost \
	--authrpc.port 8551 \
	--authrpc.jwtsecret=${MYPATH}/jwtsecret \
	>> ethersync-client.log &

# run prysm process
nohup ./prysm.sh beacon-chain \
    --mainnet \
    --datadir ${MYPATH}/data/beacon \
    --checkpoint-sync-url=https://beaconstate.info \
    --execution-endpoint=http://localhost:8551  \
    --jwt-secret=${MYPATH}/jwtsecret \
    --accept-terms-of-use \
    >> ethersync-beacon.log &
