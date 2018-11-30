
##Encrypting AMI 
aws ec2 copy-image --no-dry-run --region $region --source-image-id $i --source-region $region --region $region --name $i-encrypted-`date +%d%b%Y-%H-%M-%S` --encrypted --kms-key-id $encryptedkmskey --output text > /tmp/encryptsnap

if [ `echo $?` -ne 0 ]
then exit 1
else

###Using Encrypted AMI ID as a variable to check its creation status###
###It will not proceed further until status is in available state###

encryptsnapname=$(grep -w ami /tmp/encryptsnap | awk -F '"' '{print $1}')
encryptsnapstatus=$(aws ec2 describe-images --region $region --image-ids $encryptsnapname --output json | grep 'State' | awk -F '"' '{print $4}' | sed 's/,*$//g')
until [  "$encryptsnapstatus" == "available" ]; do
             echo "Snapshot creation is in $encryptsnapstatus state"
             sleep 60
             encryptsnapstatus=$(aws ec2 describe-images --region $region --image-ids $encryptsnapname --output json | grep "State" | awk -F '"' '{print $4}' | sed 's/,*$//g')
             done
             echo "Encrypted Snapshot $encryptsnapname is in $encryptsnapstatus state"
fi
echo "============" 


#update LC ASG with Encrypted AMI
for i in `aws --region ap-southeast-1 autoscaling describe-launch-configurations --launch-configuration-names | grep -e "ImageId" -e "LaunchConfigurationName"  | awk '{print $2}' | sed 's/"//g' | sed 's/,//g' | awk 'NR%2{printf "%s ",$0;next;}1' | grep "ami-123c1e6e" | awk '{print $1}'`
do

Iamrole=$(aws autoscaling describe-launch-configurations --launch-configuration-names $i --region ap-southeast-1 | grep IamInstanceProfile | awk -F '"' '{print $4}')
keyname=$(aws autoscaling describe-launch-configurations --launch-configuration-names $i --region ap-southeast-1 | grep KeyName | awk -F '"' '{print $4}')
securitygroup=$(aws autoscaling describe-launch-configurations --launch-configuration-names $i --region ap-southeast-1 | grep sg- | awk -F '"' '{print $2}')
instancetype=$(aws autoscaling describe-launch-configurations --launch-configuration-names $i --region ap-southeast-1 | grep InstanceType | awk -F '"' '{print $4}')

echo $Iamrole
echo $keyname
echo $securitygroup
echo $instancetype
echo ----------------------
echo Asg
# Get the ASG Attached with LC
asgname=$(aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[? contains(LaunchConfigurationName,'$i')].AutoScalingGroupName" --output text --region ap-southeast-1)

echo --------------------
echo $asgname
echo --------------
#creating New LC with Encrypted AMI

amiid-encrypted=ami-01b491dace82c7ba9
aws autoscaling create-launch-configuration --launch-configuration-name $i+Encryptecd --region ap-southeast-1 --key-name $keyname --security-groups $securitygroup --iam-instance-profile $Iamrole --instance-type $instancetype --no-ebs-optimized --instance-monitoring Enabled=true --image-id $amiid-encrypted

# Update ASG
aws autoscaling update-auto-scaling-group --auto-scaling-group-name $asgname --launch-configuration-name $i+Encryptecd

done
