#! /bin/bash

### Setup
export CFG_FIRSTNAME="Rik Tytgat"
export CFG_LOCATION=Mechelen
export CFG_NOTUSED=haha

rm -rf mytesttree
mkdir mytesttree
echo "Hello __FIRSTNAME__!" >> mytesttree/a_file.txt
echo "How are things in __LOCATION__?" >> mytesttree/a_file.txt
echo "Hello __FIRSTNAME__!" >> mytesttree/another_file.txt
echo "How are things in __LOCATION__?" >> mytesttree/another_file.txt

echo "Hello ${CFG_FIRSTNAME}!" >> mytesttree/a_file.txt.ref
echo "How are things in ${CFG_LOCATION}?" >> mytesttree/a_file.txt.ref
echo "Hello ${CFG_FIRSTNAME}!" >> mytesttree/another_file.txt.ref
echo "How are things in ${CFG_LOCATION}?" >> mytesttree/another_file.txt.ref

. ../lib.bash

### Run the test
s3_deploy_apply_config_to_tree ./mytesttree >/dev/null 2>&1

### Assess
diff mytesttree/a_file.txt.ref mytesttree/a_file.txt >/dev/null             2>&1 || exit 1
diff mytesttree/another_file.txt.ref mytesttree/another_file.txt >/dev/null 2>&1 || exit 1

### Teardown
rm -rf mytesttree
