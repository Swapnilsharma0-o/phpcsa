x=$(python -c 'import crypt,getpass; print(crypt.crypt(getpass.getpass(),crypt.mksalt(crypt.METHOD_SHA512)))')

echo "root:$x:16372:0:99999:7:::" > /home/admin/Desktop/script-stateless/shadow.temp

#pass=$(echo -n "$userInput" | sha512sum | awk '{print $1}')
#sed -i "s/password/$pass/g" shadow.temp


