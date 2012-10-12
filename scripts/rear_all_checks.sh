#!/bin/bash

for check in rear_check*
do
	/usr/lib/YaST2/bin/${check}
        retval=$?
        if [ $retval -ne 0 ]; then
		exit $reval
	fi
done

