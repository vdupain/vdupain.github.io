---
layout: post
title: Mise en place d'un VPN avec PFSense
date: 2010-10-12 11:29:44.000000000 +02:00
comments: true
categories:
- network
---

# Objectif

Accès au réseau interne d'une PME de façon sécurisée depuis un ordinateur portable (MacBook Pro) connecté à Internet avec une clé 3G.

La PME dispose déjà d'un accès Internet depuis une Livebox Pro Inventel.

# Solution

La solution consiste à mettre en place un réseau privé virtuel (VPN).

Un routeur PFSense sera mise en place, ce routeur/pare-feu sera connecté derrière une LiveBox qui fait du PPPoE vers l'ISP.

L'adresse IP publique de la LiveBox est dynamique, il faudra prévoir de créer un nom de domaine et de l'associer avec l'IP dynamique avec un service comme DynDNS par exemple.

L'interface WAN du routeur PFSense aura une adresse IP interne (192.168.2.254) avec la LiveBox comme passerelle (192.168.2.1).

Il sera donc nécessaire de reconfigurer la LiveBox pour désactiver certaines fonctions qui seront désormais prises en charge par le routeur PFSense (serveur DHCP, pare-feu, serveur OpenVPN...).

&nbsp;

[![]({{ site.url }}/assets/conf21.jpeg "conf2")]({{ site.url }}/assets/conf21.jpeg)

## Contraintes à prendre en compte

*   LiveBox Pro Inventel pour la connection à Internet.
*   Hardware: appliance [ALIX 2D13](http://www.pcengines.ch/alix2d13.htm) pour le routeur PFSense.
*   Software: routeur/pare-feu [PFSense](http://www.pfsense.org/) (version 1.2.3), basé sur FreeBSD.
*   Client OpenVPN pour MacOSX Snow Leopard: [Tunnelblick](http://code.google.com/p/tunnelblick/) ou [Viscosity](http://www.viscosityvpn.com/). Le choix se porte plutôt sur Viscosity car plus user friendly pour des non-informaticiens.

[](http://localhost:8888/wordpress/wp-content/uploads/2010/06/conf2.jpeg)

# Mise en oeuvre

## Configuration de la LiveBox

*   Accéder au menu de configuration interne de la LiveBox, généralement [http://192.168.1.1](http://192.168.1.1/)
*   Aller dans le menu "Configuration &gt; Avancée &gt; Réseau" et modifier les paramètres:

    *   Activation du serveur DHCP: décoché
    *   Adresse IP LAN: 192.168.2.1
    *   Adresse broadcast du LAN: 192.168.2.255
    *   Masque de sous-réseau: 255.255.255.0
    *   Début de la plage DHCP: 192.168.2.254
    *   Fin de la plage DHCP: 192.168.2.254
    *   Cliquer sur le bouton "Soumettre"

*   Une fois la LiveBox redémarrée, accéder à nouveau au menu de configuration, cette fois ci à l'adresse [http://192.168.2.1](http://192.168.2.1/)
*   Aller dans le menu "Configuration &gt; Avancée &gt; DNS Dynamique" et configurer le service de DNS dynamique (DynDNS dans notre cas)
*   Aller dans le menu "Configuration &gt; Avancée &gt; Routeur" et modifier les paramètres:

    *   Configurer la DMZ avec l'adresse IP 192.168.2.254, c'est l'adresse IP de l'interface WAN qui sera attribuée au routeur PFSense
    *   Configurer la redirection de port vers le routeur PFSense pour le port 1194, port du serveur OpenVPN

            *   Service: 1194
        *   Protocole: TCP
        *   Port externe: 1194
        *   Port interne: 1194
        *   Adresse IP du serveur: 192.168.2.254

*   Aller dans le menu "Sécurité &gt; Pare-feu" et changer le niveau de sécurité sur "minimum"

La LiveBox est correctement configurée, elle ne sert plus que de passerelle vers Internet.

Bien que la DMZ ait été configurée, il est quand même nécessaire de configurer le NAT et la redirection de port vers le routeur?

[![]({{ site.url }}/assets/livebox_reseau.png?w=300 "livebox_reseau")]({{ site.url }}/assets/livebox_reseau.png)

[]({{ site.url }}/assets/livebox_reseau.png)<span style="color:#0000ee;">[![]({{ site.url }}/assets/livebox_dyndns.png?w=300 "livebox_dyndns")]({{ site.url }}/assets/livebox_dyndns.png)</span>

<span style="color:#0000ee;">[![]({{ site.url }}/assets/livebox_nat_dmz.png?w=300 "livebox_nat_dmz")]({{ site.url }}/assets/livebox_nat_dmz.png)</span>

<span style="color:#0000ee;">[![]({{ site.url }}/assets/livebox_parefeu.png?w=300 "livebox_parefeu")]({{ site.url }}/assets/livebox_parefeu.png)</span>

<span style="color:#0000ee;">

</span>

## Configuration du routeur/pare-feu PFSense

### Pré-requis

*   PFSense 1.2.3 est déjà installé sur le routeur ALIX: image embedded installée sur carte Compact Flash
*   Les certificats et clés RSA ont déjà été générés grâce aux scripts easy-rsa fournis avec OpenVPN

*   Accéder à la page de configuration du routeur PFSense, [http://192.168.1.1](http://192.168.1.1/)
*   Aller dans le menu "Interfaces &gt; WAN", puis renseigner les champs suivants:

    *   Type: Static
    *   IP Address: 192.168.2.254 /24
    *   Gateway: 192.168.2.1
    *   Décocher Block private networks
    *   Décocher Block bogon networks

L'adresse IP de l'interface WAN étant une adresse privée, il faut autoriser le routage, ce qui n'est pas le cas par défaut, car bien souvent l'adresse IP WAN est une adresse publique routable sur Internet.

*   Sauvegarder les paramètres
*   Aller dans le menu "VPN &gt; OpenVPN" et sélectionner l'onglet "Server"
*   Cliquer sur "+" pour ajouter un nouveau serveur OpenVPN puis renseigner les champs suivants:

    *   Protocol: TCP
    *   Dynamic IP: coché
    *   Local port: 1194
    *   Address pool: 192.168.3.0/24
    *   Local network: 192.168.1.0/24
    *   Cryptography: AES-128-CBC
    *   Authentication method: PKI
    *   CA certificate: contenu du fichier ca.crt
    *   Server certificate: contenu du fichier server.crt
    *   Server key: contenu du fichier server.key
    *   DH parameters: contenu du fichier dh1024.pem
    *   DHCP-Opt.: DNS-Server: 192.168.1.1
    *   LZO compression: coché
    *   Custom options: engine cryptodev;management 127.0.0.1 1194;

Le paramètre de cryptographie "AES-128-CBC" et l'option "engine cryptodev"  permettent de profiter de l'accélération matériel AES 128 bits de la carte ALIX 2D13 pour le cryptage/décryptage des clés de chiffrement.

*   Sauvegarder les paramètres. Une règle sera automatiquement crée pour autoriser les connexions entrantes sur le port 1194 de l'interface WAN

[![]({{ site.url }}/assets/interface_wan_1.png?w=300 "interface_wan_1")]({{ site.url }}/assets/interface_wan_1.png)

[![]({{ site.url }}/assets/interface_wan_2.png?w=300 "interface_wan_2")]({{ site.url }}/assets/interface_wan_2.png)

[![]({{ site.url }}/assets/openvpn_1.png?w=300 "openvpn_1")]({{ site.url }}/assets/openvpn_1.png)

[![]({{ site.url }}/assets/openvpn_2.png?w=300 "openvpn_2")]({{ site.url }}/assets/openvpn_2.png)

[![]({{ site.url }}/assets/openvpn_3.png?w=300 "openvpn_3")]({{ site.url }}/assets/openvpn_3.png)

## Configuration du portable MacBook Pro

*   Installer le client OpenVPN [Viscosity](http://www.viscosityvpn.com/)
*   Aller dans le menu "Préférences" et créer une nouvelle connexion:
*   Dans l'onglet "Général"

    *   Connexion: entrer un nom au choix
    *   Serveur distant: mettre l'adresse telle que configurée dans le menu "DNS Dynamique" de la LiveBox
    *   Port: 1194
    *   Protocole: TCP
    *   Type: tun
    *   Activer le support DNS

*   Dans l'onglet "Certificats"

    *   Mettre le CA certificat (ca.crt)
    *   Mettre le certificate (cert.crt)
    *   Mettre la clé du client (.key)

*   Dans l'onglet "Options

    *   Activer la compression LZO
    *   Cocher l'option "Persist Tun"
    *   Cocher l'option "Persist Key"
    *   Cocher l'option "Options Pull"

*   Dans l'onglet "Avancés, ajouter les options:

    *   float
    *   cipher AES-128-CBC
    *   resolv-retry infinite
    *   tls-client
    *   ns-cert-type server

[![]({{ site.url }}/assets/viscosity_preferences.png?w=300 "viscosity_preferences")]({{ site.url }}/assets/viscosity_preferences.png)

[![]({{ site.url }}/assets/viscosity_prefs_general.png?w=300 "viscosity_prefs_general")]({{ site.url }}/assets/viscosity_prefs_general.png)

[![]({{ site.url }}/assets/viscosity_prefs_certificats.png?w=300 "viscosity_prefs_certificats")]({{ site.url }}/assets/viscosity_prefs_certificats.png)

[![]({{ site.url }}/assets/viscosity_prefs_options.png?w=300 "viscosity_prefs_options")]({{ site.url }}/assets/viscosity_prefs_options.png)

[![]({{ site.url }}/assets/viscosity_prefs_reseau.png?w=300 "viscosity_prefs_reseau")]({{ site.url }}/assets/viscosity_prefs_reseau.png)

[![]({{ site.url }}/assets/viscosity_prefs_proxy.png?w=300 "viscosity_prefs_proxy")]({{ site.url }}/assets/viscosity_prefs_proxy.png)

[![]({{ site.url }}/assets/viscosity_prefs_avances.png?w=300 "viscosity_prefs_avances")]({{ site.url }}/assets/viscosity_prefs_avances.png)
