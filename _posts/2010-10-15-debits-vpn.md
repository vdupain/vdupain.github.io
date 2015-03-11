---
layout: post
title: Débits VPN
date: 2010-10-15
comments: true
categories: network
---

Suite à la mise en place d'un VPN (OpenVPN) avec un routeur sous PFSense, j'ai voulu mesurer les débits et voir l'impact de l'accélération AES du processeur AMD Geode LX présent sur la carte [ALIX 2D3](http://www.pcengines.ch/alix2d13.htm).

Tout d'abord, vérifions la présence du module d'accélération matériel et sa prise en charge par PFSense (FreeBSD 7.2 sous le capot de PFSense 1.2.3), je lance une commande dmesg sur le routeur pour en savoir un peu plus...

<pre>
[admin@firewall]/root: dmesg
...
glxsb0: &lt;AMD Geode LX Security Block (AES-128-CBC, RNG)&gt; mem 0xefff4000-0xefff7fff irq 9 at device 1.2 on pci0
...
</pre>

Le module glxsb est bien chargé.

## Benchmarking avec openssl

OpenVPN s'appuie sur **openssl** pour les fonctionnalités de chiffrement, d'authentification et de certification.

Parmi les différentes possibilités qu'offrent openssl, l'une d'elles permet de mesurer les vitesses des algorithmes de chiffrement, on va donc exécuter ces commandes avec et sans l'accélération matériel activée.

Pour les options openssl:

*   -elapsed        measure time in real time instead of CPU user time. Pourquoi donc utiliser cette option: "The other thing is, using the "cryptodev" engine causes most of the actual work to be done in the kernel.  So you need -elapsed on the openssl speed command line or you'll get false, insanely high results because it will track only the amount of time spent in the user space openssl process."
*   -engine e       use engine e, possibly a hardware device.
*   -evp                force to use the EVP layer

```
[admin@firewall]/root(6): openssl speed -elapsed -evp aes-128-cbc
...
type             16 bytes     64 bytes    256 bytes   1024 bytes   8192 bytes
aes-128-cbc       4875.59k     5368.59k     5531.36k     5588.73k     5580.94k
[admin@firewall]/root(7): openssl speed -elapsed -evp aes-128-cbc -engine cryptodev
engine "cryptodev" set.
...
type             16 bytes     64 bytes    256 bytes   1024 bytes   8192 bytes
aes-128-cbc        575.50k     2220.60k     7681.98k    19713.05k    32697.50k
```
On voit nettement l'effet de la crypto matérielle AES avec la taille des blocs de données qui augmente.

[![]({{ site.url }}/assets/benchmark_openssl_speed1.png "benchmark_openssl_speed")]({{ site.url }}/assets/benchmark_openssl_speed1.png)

## Mesures de débit

Ensuite pour mesurer les débits IP, j'utilise **[iperf](http://sourceforge.net/projects/iperf/)**.

**iperf** est un outil très utile pour effectuer différentes mesures d'un réseau IP: bande passante, latence, jitter, perte de paquets, en TCP/UDP, débit montant/descendant, etc...

iperf fonctionne en mode client/serveur, son utilisation est très simple, pour en savoir un peu plus sur cet outil:

* [http://openmaniak.com/fr/iperf.php](http://openmaniak.com/fr/iperf.php)
* [http://www.projet-plume.org/fr/fiche/iperf](http://www.projet-plume.org/fr/fiche/iperf)

Le protocole et les conditions du tests sont les suivants:

*   2 instances de serveur OpenVPN installée sur mon routeur/pare-feu PFSense 1.2.3
    *   1 serveur OpenVPN en TCP sur le port 1194 **avec** l'accélération matériel (engine cryptodev)
    *   1 serveur OpenVPN en TCP sur le port 1195 **sans** l'accélération matériel

[![]({{ site.url }}/assets/serveurs_openvpn.png "serveurs_openvpn")]({{ site.url }}/assets/serveurs_openvpn.png)

*   Algorithme de crypto: AES-128-CBC
*   Les tests ont lieu avec une liaison Ethernet 100 Mbits Full Duplex

*   Mesure de référence: connexion au serveur distant en TCP/IP sur un lien 100 Mbits Full Duplex
*   Mesure par une connexion VPN  sans chiffrement matériel
*   Mesure par une connexion VPN avec chiffrement matériel (engine cryptodev)

### Mesure de référence

```
MacBook-Pro-de-Vince:~ vince$ iperf -c firewall -t 60 -i 10
------------------------------------------------------------
Client connecting to firewall, TCP port 5001
TCP window size: 64.7 KByte (default)
------------------------------------------------------------
[  3] local 192.168.1.220 port 62259 connected with 192.168.1.1 port 5001
[ ID] Interval       Transfer     Bandwidth
[  3]  0.0-10.0 sec    110 MBytes  92.4 Mbits/sec
[ ID] Interval       Transfer     Bandwidth
[  3] 10.0-20.0 sec    110 MBytes  92.5 Mbits/sec
[ ID] Interval       Transfer     Bandwidth
[  3] 20.0-30.0 sec    110 MBytes  92.6 Mbits/sec
[ ID] Interval       Transfer     Bandwidth
[  3] 30.0-40.0 sec    110 MBytes  91.9 Mbits/sec
[ ID] Interval       Transfer     Bandwidth
[  3] 40.0-50.0 sec    109 MBytes  91.1 Mbits/sec
[ ID] Interval       Transfer     Bandwidth
[  3]  0.0-60.0 sec    659 MBytes  92.1 Mbits/sec
```

Nous ne sommes pas loin du débit théorique des 100 Mbits/sec.

### Mesure par une connexion VPN sans chiffrement matériel

```
macbookpro:~ vince$ iperf -c 192.168.3.1 -t 60 -i 10
------------------------------------------------------------
Client connecting to 192.168.3.1, TCP port 5001
TCP window size: 64.0 KByte (default)
------------------------------------------------------------
[  3] local 192.168.3.6 port 62274 connected with 192.168.3.1 port 5001
[ ID] Interval       Transfer     Bandwidth
[  3]  0.0-10.0 sec  10.3 MBytes  8.64 Mbits/sec
[ ID] Interval       Transfer     Bandwidth
[  3] 10.0-20.0 sec  10.5 MBytes  8.84 Mbits/sec
[ ID] Interval       Transfer     Bandwidth
[  3] 20.0-30.0 sec  10.3 MBytes  8.64 Mbits/sec
[ ID] Interval       Transfer     Bandwidth
[  3] 30.0-40.0 sec  10.4 MBytes  8.72 Mbits/sec
[ ID] Interval       Transfer     Bandwidth
[  3] 40.0-50.0 sec  9.83 MBytes  8.24 Mbits/sec
[ ID] Interval       Transfer     Bandwidth
[  3]  0.0-60.0 sec  61.9 MBytes  8.65 Mbits/sec
```

### Mesure par une connexion VPN avec chiffrement matériel

```
macbookpro:~ vince$ iperf -c 192.168.2.1 -t 60 -i 10
------------------------------------------------------------
Client connecting to 192.168.2.1, TCP port 5001
TCP window size: 64.0 KByte (default)
------------------------------------------------------------
[  3] local 192.168.2.6 port 62265 connected with 192.168.2.1 port 5001
[ ID] Interval       Transfer     Bandwidth
[  3]  0.0-10.0 sec  10.9 MBytes  9.16 Mbits/sec
[ ID] Interval       Transfer     Bandwidth
[  3] 10.0-20.0 sec  10.9 MBytes  9.12 Mbits/sec
[ ID] Interval       Transfer     Bandwidth
[  3] 20.0-30.0 sec  10.9 MBytes  9.14 Mbits/sec
[ ID] Interval       Transfer     Bandwidth
[  3] 30.0-40.0 sec  11.1 MBytes  9.31 Mbits/sec
[ ID] Interval       Transfer     Bandwidth
[  3] 40.0-50.0 sec  10.8 MBytes  9.03 Mbits/sec
[ ID] Interval       Transfer     Bandwidth
[  3]  0.0-60.0 sec  65.3 MBytes  9.13 Mbits/sec
```
## Conclusion

[![]({{ site.url }}/assets/mesures_de_debits_avec_iperf1.png "mesures_de_débits_avec_iperf")]({{ site.url }}/assets/mesures_de_debits_avec_iperf1.png)

[![]({{ site.url }}/assets/benchmarks_debits_vpn1.png "benchmarks_débits_vpn")]({{ site.url }}/assets/benchmarks_debits_vpn1.png)

[]({{ site.url }}/assets/benchmarks_debits_vpn.png)

L'écart de performance entre l'activation ou non de l'accélération matériel n'est pas flagrant contrairement à ce que laissait penser les mesures de vitesse d'algorithme de chiffrement avec openssl.

Après avoir fait quelques recherches sur Google, je suis tombé sur quelques explications au sujet du driver glxsb : le driver n'est pas très efficace, il y a un overhead sur les appels systèmes qui plombe les performances sauf avec des tailles de blocs vraiment important, ce que semble confirmer le benchmark openssl.

Même si le gain sur le débit n'est donc pas énorme, n'oublions pas que l'accélération matériel a quand même l'avantage de réduire la charge CPU, ce qui n'est déjà pas si mal.

## Références

* [http://doc.pfsense.org/index.php/Are_cryptographic_accelerators_supported](http://doc.pfsense.org/index.php/Are_cryptographic_accelerators_supported)
* [http://www.feyrer.de/NetBSD/bx/blosxom.cgi/index.front?-tags=geode](http://www.feyrer.de/NetBSD/bx/blosxom.cgi/index.front?-tags=geode)

