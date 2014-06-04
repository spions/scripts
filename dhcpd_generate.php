<?php

$file_array = file("net.txt");

//var_dump($file_array);

    for ($i=0; $i<=32; $i++) {
        $masks[$i]   = (pow(2,$i)-1)<<(32-$i);
         $cimasks[$i] = (pow(2,32-$i)-1);

    };

foreach ($file_array as $aData) {

    list ($txt_gateway,$masklen,$comment) = explode("   ",$aData);

    $gateway = ip2long($txt_gateway);
    $mask = $masks[$masklen];
    $net     = $gateway & $mask;

    if ($net==$gateway) {$txt_gateway=long2ip($gateway+1);}

    $broadcast = $gateway | $cimasks[$masklen];

    $ifsettings = array(
                        "net"           => long2ip($net),
                        "mask"          => long2ip($mask),
                        "gateway"       => $txt_gateway,
                        "broadcast"     => long2ip($broadcast),
                        "first"         => long2ip($net+2),
                        "last"          => long2ip($broadcast-1),
                );



//    print_r($ifsettings);
    echo "#".$comment."\n";
    echo "subnet ".$ifsettings["net"]." netmask ".$ifsettings["mask"]." {\n";
    echo "    ddns-update-style interim;\n";
    echo "    ddns-updates on;\n";
    echo "    ddns-hostname = binary-to-ascii (16, 8, \"-\", substring (hardware, 1, 6));\n";
    echo "    ddns-domainname \"my.domain.ru\";\n";
    echo "    ddns-rev-domainname \"in-addr.arpa\";\n";
    echo "    option domain-name-servers ip-dns1 ip-dns2;\n";
    echo "\n";
    echo "    pool {\n";
    echo "       range ".$ifsettings["first"]." ".$ifsettings["last"].";\n";
    echo "       option subnet-mask ".$ifsettings["mask"].";\n";
    echo "       option routers ".$ifsettings["gateway"].";\n";
    echo "    }\n";
    echo "}\n";
}

?>
