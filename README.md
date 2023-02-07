# Measure-Cluster-Pre-And-Post-ReadyTime

## Purpose
The purpose of this script is to measure the number of VMs experiencing ready time before and after a change.

Other options are available ei: vROPS, but this script filters out VMs with low CPU usage.

In a loaded cluster VM's that have low CPU usage might experience more ready times than others. This script will look for readytime above 3% (configurable) and check the cpu usage in the same interval, and if the cpu usage is below 20%, then measurement wil not be counted.

## Usage
Configure the maintenance date. This is the date you made the change. There is a start data and a end date to accomendate for changes happening overe multiple days. The days set af start and end are not measured.

You might need to change the interval if you are not getting any results. Normally you have metrics every 2 hours for 30 days, above that you might have to set the interval to everyone days. Measured in seconds. The longer the interval the more unprecise the calculations will be.
