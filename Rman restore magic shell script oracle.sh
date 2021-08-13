#!/bin/bash
_env(){
RESTORE_PROGRESS=/tmp/restore_progress.log
export PATH=/apps01/product/12.1.0/dbhome_1/bin:/usr/sbin:/usr/lib64/qt-3.3/bin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/oracle/.local/bin:/home/oracle/bin
export ORACLE_HOME=/apps01/product/12.1.0/dbhome_1
export ORACLE_SID=orcl19x
touch alrtlog
export ALRTLOG=alrtlog
ERROR_LOG=restore.err
RSTORE=/home/oracle/dbsz.txt
ela_s=$(date +%s)
}
_alrtlog(){
$ORACLE_HOME/bin/sqlplus -S "/ as sysdba" << EOF > $ALRTLOG
select VALUE from v\$diag_info where NAME='Diag Trace';
EOF
}
_restore_pct(){
while sleep 0.5;do
cat /dev/null > $RSTORE
date_is=$(date "+%F-%H-%M-%S")
#echo "============================================================"+
#echo "         ----->$ORACLE_SID<-----                                |"|tr 'a-z' 'A-Z';echo "    Restore progress ($date_is)                  |"
#echo "============================================================"+
$ORACLE_HOME/bin/sqlplus -S "/ as sysdba" << EOF > $RSTORE
set feedback off
set lines 200
set pages 1000
set termout off
col INPUT_BYTES/1024/1024 format 9999999
col OUTPUT_BYTES/1024/1024 format 9999999
col OBJECT_TYPE format a10
set serveroutput off
spool dbsz.out
variable s_num number;
BEGIN
  select trunc(sum(dbsize)) into :s_num
from
 (select file#,sum((datafile_blocks * 8) / 1024) / count(*) as dbsize
from v\$backup_datafile
 group by file#);
  dbms_output.put_line(:s_num);
END;
/
set feedback on
select decode(INPUT_BYTES/1048576,0,'ZERO') as IN_BYTE,OUTPUT_BYTES/1048576 as OUT_BYTE,OBJECT_TYPE,100*((OUTPUT_BYTES/1048576)/:s_num) as PCTDONE,:s_num as TOTALDATA,(select avg(EFFECTIVE_BYTES_PER_SECOND)/1048576 from v\$backup_async_io) IO_THROUGHPUT from v\$rman_status where status like '%RUNNING%';
spool off
EOF
pct="$(sed '/^$/d' $RSTORE|grep -Ev 'row|ZERO|-|PCT'|awk '{print $4}'|tail -1)"
done="$(sed '/^$/d' $RSTORE|grep -Ev 'row|ZERO|-|PCT'|awk '{print $1}'|tail -1)"
totdata="$(sed '/^$/d' $RSTORE|grep -Ev 'row|ZERO|-|PCT'|awk '{print $5}'|tail -1)"
ETA_0="$(sed '/^$/d' $RSTORE|grep -Ev 'row|ZERO|-|PCT'|awk '{print $6}'|tail -1)"
ETA_1=$(echo "scale=2;($totdata - $done) / $ETA_0"|bc -l)
#ETA_1=$(echo "scale=2;$done / 0.02 "|bc -l)
clear
echo "======================================================================"
echo "$date_is|Current restore progress for $ORACLE_SID:[$pct]%         "
echo "======================================================================"
echo "<><><><><><><><><><>|$done(MB) restored out of $totdata(MB)     "
echo "======================================================================"
echo "<><><><><><><><><><>|Estimated time remaining to complete:$ETA_1 sec        "
echo "======================================================================"
echo "======================================================================"
echo "<><><><><><><><><><>|RMAN IO THROUGHPUT ===========> $ETA_0         "
echo "======================================================================"
sed '/^$/d' $RSTORE|grep 'DB FULL' >/dev/null 2>&1
if [ $? -ne 0 ]
then
timeout 1 tail -10f $ALRTLOG|grep -q 'restore complete'
echo "Restore completed successfully!"
break
fi
if timeout 1 tail -10f $ALRTLOG|egrep 'ORA-|RMAN-|ERROR'
then
tail -10f $ALRTLOG|egrep 'ORA-|RMAN-|ERROR' >> $ERROR_LOG
echo "======================================================================"
echo "                       Errors found in $ERROR_LOG file!!"
echo "======================================================================"
echo "                       Error list "; cat $ERROR_LOG
else
echo "======================================================================"
echo "                     No errors so far !!"
echo "======================================================================"
fi
#while sleep 0.5;
#do
#currt=$(shuf -i1-1000 -n1)
#lastt=$(shuf -i1-10000 -n1)
if timeout 1 tail -10f $ALRTLOG|grep -q 'restore complete'
then
echo "======================================================================"
echo "                    Restore completed successfully!"
echo "======================================================================"
break
fi
#cat $SIZELOG|grep -v 'PL'
#cat /dev/null > $SIZELOG
done
ela_e=$(date +%s)
}
#currt=$(shuf -i1-1000 -n1)
#lastt=$(shuf -i1-10000 -n1)
#lastdone="$(cat dbsz.txt|grep -v 'row'|tail -3|grep -v '^$'|awk '{print $2}')"
#sofar=$lastdone
#echo -ne "█";
#echo "elapsed_time: $($ela_e - $ela_s)

_ETA(){
c=0
at=0
sleep=30
#while sleep 0.5;
#do
#currt=$(shuf -i1-1000 -n1)
#lastt=$(shuf -i1-10000 -n1)
while true
do
sofar="$(cat dbsz.txt|grep -v 'row'|tail -3|grep -v '^$'|awk '{print $2}')"
sleep $sleep
lastdone="$(cat dbsz.txt|grep -v 'row'|tail -3|grep -v '^$'|awk '{print $2}')"
#lastdone="$(cat dbsz.txt|grep -v 'row'|tail -3|grep -v '^$'|awk '{print $2}')"
ETA_0=$(echo "scale=2;($lastdone - $sofar) / $sleep"|bc -l)
sofar=$lastdone
let c=$c+1
at=$(echo "scale=2;$at + $ETA_0"|bc -l)
a=$(echo "scale=2;$at / $c"|bc -l)
if [ "$a" != "0" ]
then
ETA_1=$(echo "scale=2;($totdata - $lastdone)/ $a / 60 "|bc -l)
clear
echo "Estimated time to complete:$ETA_1 min"
fi
done
}

_ela_t(){
echo "Total elapsed time:$(($ela_e - $ela_s))"
}
#_ETA &
_env
_alrtlog
_restore_pct
_ela_t
