Product_Path=$1
App_Version=$2
App_Name=$3
BundleId=$4

APP_KEY=$5
APP_ID=$6

for I in `ls`
do
    echo "product ls" $I
    if [[ $I =~ "archive" ]] 
    then
    ArchiveFolder=$I
    fi
done

cd ${ArchiveFolder}/dSYMs

mv $ArchiveFolder/dSYMs/${Scheme_Name}.app.dSYM ${App_Name}.dSYM

for I in `ls`
do
    echo "dsym ls" $I
    rm -f dSYMs.zip
    zip -q -r dSYMs.zip $I

    curl -k "https://api.bugly.qq.com/openapi/file/upload/symbol?app_key=${APP_KEY}&app_id=${APP_ID}" --form "api_version=1" --form "app_id=${APP_ID}" --form "app_key=${APP_KEY}" --form "symbolType=2"  --form "bundleId=${BundleId}" --form "productVersion=${App_Version}" --form "fileName=dSYMs.zip" --form "file=@dSYMs.zip" --verbose
done


