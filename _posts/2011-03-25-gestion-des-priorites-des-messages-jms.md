---
layout: post
title: Gestion des priorités des messages JMS
date: 2011-03-25 14:40:02.000000000 +01:00
comments: true
categories:
- developpement
---

# Objectif

Ce Quick Start Guide JMS a pour but de montrer simplement comment poster des messages dans une file JMS et de les consommer par ordre de priorité comme illustré par le schéma suivant:

[![]({{ site.url }}/assets/resequencer.gif "Resequencer")](http://www.eaipatterns.com/Resequencer.html)

Cet exemple a été réalisé et testé dans l'environnement suivant:

*   Java 6
*   Maven 2.2.1 et 3.0.2
*   Provider JMS ActiveMQ 5.4.2: la priorité des message est fonctionnelle depuis la version [5.4.0](http://activemq.apache.org/new-features-in-54.html)
*   Provider JMS JBoss Messaging 1.4.0.x (demande à uploader certaines librairies dans son repo local maven car non disponibles dans le repo central et le [repo JBoss](http://repository.jboss.org/maven2/))

# La partie Développement

## Création du projet avec Maven

Tout d'abord, nous allons créer un projet **maven** avec le plugin **archetype**:

<pre>$ mvn --batch-mode archetype:generate -DarchetypeArtifactId=maven-archetype-quickstart -DgroupId=com.mycompany.messaging -DartifactId=messaging -Dversion=1.0.0</pre>

### Configuration du pom.xml

Il faut ensuite modifier le fichier **pom.xml** pour:

*   ajouter les dépendances vers les librairies JMS et le provider JMS ActiveMQ
*   ajouter la configuration du plugin ActiveMQ pour lancer le provider JMS

[sourcecode language="xml"]

&lt;project xmlns=&quot;http://maven.apache.org/POM/4.0.0&quot; xmlns:xsi=&quot;http://www.w3.org/2001/XMLSchema-instance&quot;

  xsi:schemaLocation=&quot;http://maven.apache.org/POM/4.0.0 http://maven.apache.org/maven-v4_0_0.xsd&quot;&gt;

  &lt;modelVersion&gt;4.0.0&lt;/modelVersion&gt;

  &lt;groupId&gt;com.mycompany.messaging&lt;/groupId&gt;

  &lt;artifactId&gt;messaging&lt;/artifactId&gt;

  &lt;packaging&gt;jar&lt;/packaging&gt;

  &lt;version&gt;1.0.0&lt;/version&gt;

  &lt;name&gt;messaging&lt;/name&gt;

  &lt;url&gt;http://maven.apache.org&lt;/url&gt;

  &lt;dependencies&gt;

    &lt;dependency&gt;

      &lt;groupId&gt;junit&lt;/groupId&gt;

      &lt;artifactId&gt;junit&lt;/artifactId&gt;

      &lt;version&gt;3.8.1&lt;/version&gt;

      &lt;scope&gt;test&lt;/scope&gt;

    &lt;/dependency&gt;

    &lt;dependency&gt;

      &lt;groupId&gt;javax.jms&lt;/groupId&gt;

      &lt;artifactId&gt;jms&lt;/artifactId&gt;

      &lt;version&gt;1.1&lt;/version&gt;

    &lt;/dependency&gt;

    &lt;dependency&gt;

      &lt;groupId&gt;org.apache.activemq&lt;/groupId&gt;

      &lt;artifactId&gt;activemq-core&lt;/artifactId&gt;

      &lt;version&gt;5.4.2&lt;/version&gt;

    &lt;/dependency&gt;

  &lt;/dependencies&gt;

  &lt;build&gt;

    &lt;plugins&gt;

      &lt;plugin&gt;

        &lt;groupId&gt;org.apache.activemq.tooling&lt;/groupId&gt;

        &lt;artifactId&gt;maven-activemq-plugin&lt;/artifactId&gt;

        &lt;version&gt;5.4.2&lt;/version&gt;

        &lt;configuration&gt;

          &lt;configUri&gt;xbean:file:./conf/activemq.xml&lt;/configUri&gt;

          &lt;fork&gt;false&lt;/fork&gt;

          &lt;systemProperties&gt;

            &lt;property&gt;

              &lt;name&gt;javax.net.ssl.keyStorePassword&lt;/name&gt;

              &lt;value&gt;password&lt;/value&gt;

            &lt;/property&gt;

            &lt;property&gt;

              &lt;name&gt;org.apache.activemq.default.directory.prefix&lt;/name&gt;

              &lt;value&gt;./target/&lt;/value&gt;

            &lt;/property&gt;

          &lt;/systemProperties&gt;

        &lt;/configuration&gt;

        &lt;dependencies&gt;

          &lt;dependency&gt;

            &lt;groupId&gt;org.springframework&lt;/groupId&gt;

            &lt;artifactId&gt;spring&lt;/artifactId&gt;

            &lt;version&gt;2.5.5&lt;/version&gt;

          &lt;/dependency&gt;

          &lt;dependency&gt;

            &lt;groupId&gt;org.mortbay.jetty&lt;/groupId&gt;

            &lt;artifactId&gt;jetty-xbean&lt;/artifactId&gt;

            &lt;version&gt;6.1.11&lt;/version&gt;

          &lt;/dependency&gt;

          &lt;dependency&gt;

            &lt;groupId&gt;org.apache.camel&lt;/groupId&gt;

            &lt;artifactId&gt;camel-activemq&lt;/artifactId&gt;

            &lt;version&gt;1.1.0&lt;/version&gt;

          &lt;/dependency&gt;

        &lt;/dependencies&gt;

      &lt;/plugin&gt;

    &lt;/plugins&gt;

  &lt;/build&gt;

&lt;/project&gt;

[/sourcecode]

### Le plugin maven-activemq-plugin

ActiveMQ fournit un plugin maven 2 **maven-activemq-plugin** pour démarrer facilement un provider JMS. La configuration de ce plugin étant déjà faite dans le fichier pom.xml, il reste à créer un fichier de configuration **activemq.xml** dans un répertoire **conf** à la racine de notre projet.

Créer un fichier conf/activemq.xml:

[sourcecode language="xml"]

&lt;?xml version=&quot;1.0&quot;?&gt;

&lt;beans xmlns=&quot;http://www.springframework.org/schema/beans&quot; xmlns:amq=&quot;http://activemq.apache.org/schema/core&quot;

  xmlns:xsi=&quot;http://www.w3.org/2001/XMLSchema-instance&quot;

  xsi:schemaLocation=&quot;http://www.springframework.org/schema/beans

  http://www.springframework.org/schema/beans/spring-beans-2.0.xsd

  http://activemq.apache.org/schema/core

  http://activemq.apache.org/schema/core/activemq-core.xsd

  &quot;&gt;

  &lt;broker xmlns=&quot;http://activemq.apache.org/schema/core&quot; brokerName=&quot;localhost&quot; dataDirectory=&quot;./data&quot;&gt;

    &lt;!-- The transport connectors ActiveMQ will listen to --&gt;

    &lt;transportConnectors&gt;

      &lt;transportConnector name=&quot;openwire&quot; uri=&quot;tcp://localhost:61616&quot; /&gt;

    &lt;/transportConnectors&gt;

  &lt;/broker&gt;

&lt;/beans&gt;

[/sourcecode]

### Support JNDI

Il est nécessaire de récupérer certaines informations depuis un contexte JNDI pour créer une connexion au provider JMS ActiveMQ.

Créer un fichier **jndi.properties** dans le répertoire **src/main/resources**

[sourcecode language="text"]

java.naming.factory.initial=org.apache.activemq.jndi.ActiveMQInitialContextFactory

java.naming.provider.url=tcp://localhost:61616

queue.queue1 = example.queue1

[/sourcecode]

Ensuite, nous allons créer un Producer et un Consumer pour poster et consommer les messages.

## Le Producer

Nous allons créer un Producer qui envoie des messages à la file de messages. Le Producer prendra en paramètre:

*   la file de messages de destination
*   le nombre de messages à envoyer. Si non renseigné, un seul message sera envoyé
*   la priorité des messages. Si non renseignée, la priorité est aléatoire (entre 0 et 9)

Créer une classe **Producer** dans le répertoire **src/main/java/com/mycompany/messaging**:

[sourcecode language="java"]

package com.mycompany.messaging;

import javax.jms.Connection;

import javax.jms.ConnectionFactory;

import javax.jms.DeliveryMode;

import javax.jms.Destination;

import javax.jms.JMSException;

import javax.jms.Message;

import javax.jms.MessageProducer;

import javax.jms.Session;

import javax.jms.TextMessage;

import javax.naming.Context;

import javax.naming.InitialContext;

import javax.naming.NamingException;

public class Producer {

    public static void main(String[] args) {

        Context jndiContext = null;

        ConnectionFactory connectionFactory = null;

        Connection connection = null;

        Session session = null;

        Destination destination = null;

        MessageProducer producer = null;

        String destinationName = null;

        int numMsgs = 1;

        int priority = -1;

        if ((args.length &lt; 1) || (args.length &gt; 3)) {

            System.out

                            .println(&quot;Usage: java Producer &lt;destination-name&gt; [&lt;number-of-messages&gt;] [&lt;priority-of-messages&gt;]&quot;);

            System.exit(1);

        }

        destinationName = args[0];

        System.out.println(&quot;Destination name is &quot; + destinationName);

        if (args.length &gt;= 2) {

            numMsgs = Integer.valueOf(args[1]);

        }

        if (args.length == 3) {

            priority = Integer.valueOf(args[2]);

        }

        try {

            jndiContext = new InitialContext();

            connectionFactory = (ConnectionFactory ) jndiContext.lookup(&quot;ConnectionFactory&quot;);

            destination = (Destination ) jndiContext.lookup(destinationName);

        } catch (NamingException e) {

            e.printStackTrace();

            System.exit(1);

        }

        try {

            connection = connectionFactory.createConnection();

            session = connection.createSession(false, Session.AUTO_ACKNOWLEDGE);

            producer = session.createProducer(destination);

            TextMessage message = session.createTextMessage();

            for (int i = 0; i &lt; numMsgs; i++) {

                message.setText(&quot;This is message &quot; + i);

                int p = priority;

                if (priority == -1) {

                    p = (int ) (Math.random() * 10);

                }

                System.out.println(&quot;Sending message: &quot; + message.getText() + &quot; with priority: &quot; + p);

                producer.send(message, DeliveryMode.PERSISTENT, p, Message.DEFAULT_TIME_TO_LIVE);

            }

        } catch (JMSException e) {

            e.printStackTrace();

        } finally {

            try {

                jndiContext.close();

            } catch (NamingException e1) {

            }

            if (connection != null) {

                try {

                    connection.stop();

                    connection.close();

                } catch (JMSException e) {

                }

            }

        }

    }

}

[/sourcecode]

## Le Consumer

Nous allons créer un Consumer qui consomme les messages de la file. Le Consumer prendra en paramètre:

*   la file de messages

Créer une classe **Consumer** dans le répertoire **src/main/java/com/mycompany/messaging**:

[sourcecode language="java"]

package com.mycompany.messaging;

import javax.jms.Connection;

import javax.jms.ConnectionFactory;

import javax.jms.ConnectionMetaData;

import javax.jms.Destination;

import javax.jms.JMSException;

import javax.jms.Message;

import javax.jms.MessageConsumer;

import javax.jms.Session;

import javax.jms.TextMessage;

import javax.naming.Context;

import javax.naming.InitialContext;

import javax.naming.NamingException;

public class Consumer {

    public static void main(String[] args) {

        Context jndiContext = null;

        ConnectionFactory connectionFactory = null;

        Connection connection = null;

        Session session = null;

        Destination destination = null;

        MessageConsumer consumer = null;

        String destinationName = null;

        if ((args.length &lt; 1) || (args.length &gt; 1)) {

            System.out.println(&quot;Usage: java Consumer &lt;destination-name&gt;&quot;);

            System.exit(1);

        }

        destinationName = args[0];

        System.out.println(&quot;Destination name is &quot; + destinationName);

        try {

            jndiContext = new InitialContext();

            connectionFactory = (ConnectionFactory ) jndiContext.lookup(&quot;ConnectionFactory&quot;);

            destination = (Destination ) jndiContext.lookup(destinationName);

        } catch (NamingException e) {

            e.printStackTrace();

            System.exit(1);

        }

        try {

            connection = connectionFactory.createConnection();

            connection.start();

            session = connection.createSession(false, Session.AUTO_ACKNOWLEDGE);

            consumer = session.createConsumer(destination);

            while (true) {

                Message message = consumer.receive(2000);

                if (message == null) {

                    System.out.println(&quot;waiting...&quot;);

                    continue;

                }

                if (message instanceof TextMessage) {

                    TextMessage txtMessage = (TextMessage ) message;

                    System.out.println(&quot;Message received: &quot; + txtMessage.getText() + &quot;, priority:&quot;

                                    + txtMessage.getJMSPriority());

                } else {

                    System.out.println(&quot;Invalid message received.&quot;);

                }

                Thread.sleep(100);

            }

        } catch (Exception e) {

            e.printStackTrace();

        } finally {

            try {

                jndiContext.close();

            } catch (NamingException e) {

                e.printStackTrace();

            }

            try {

                connection.close();

            } catch (JMSException e) {

                e.printStackTrace();

            }

        }

    }

}

[/sourcecode]

# La partie Build  et Run

## Run du Prodiver JMS

Pour lancer le provider JMS ActiveMQ, il suffit d'exécuter la commande maven suivante:

<pre>$ mvn activemq:run
...
INFO: ActiveMQ JMS Message Broker (localhost, ID:GF106903-1477-1301046394468-0:1) started</pre>

Le provider JMS ActiveMQ est démarré!

## Envoi des messages

Créer 10 messages de priorité aléatoire (0 à 9) et les poster dans la file de messages "queue1":

<pre>$ mvn clean compile exec:java -Dexec.mainClass=com.mycompany.messaging.Producer -Dexec.args="queue1 10"
...
Sending message: This is message 0 with priority: **<span style="color:red;">8</span>**
Sending message: This is message 1 with priority: **<span style="color:red;">9</span>**
Sending message: This is message 2 with priority: **<span style="color:red;">4</span>**
Sending message: This is message 3 with priority: **<span style="color:red;">6</span>**
Sending message: This is message 4 with priority: **<span style="color:red;">2</span>**
Sending message: This is message 5 with priority: **<span style="color:red;">8</span>**
Sending message: This is message 6 with priority: **<span style="color:red;">8</span>**
Sending message: This is message 7 with priority: **<span style="color:red;">8</span>**
Sending message: This is message 8 with priority: **<span style="color:red;">9</span>**
Sending message: This is message 9 with priority: **<span style="color:red;">0</span>**
...</pre>

## Consommation des messages

Consommer les messages depuis la file de message "queue1":

<pre>$ mvn clean compile exec:java -Dexec.mainClass=com.mycompany.messaging.Consumer -Dexec.args="queue1"
...
Message received: This is message 1, priority:**<span style="color:red;">9</span>**
Message received: This is message 8, priority:**<span style="color:red;">9</span>**
Message received: This is message 0, priority:**<span style="color:red;">8</span>**
Message received: This is message 5, priority:**<span style="color:red;">8</span>**
Message received: This is message 6, priority:**<span style="color:red;">8</span>**
Message received: This is message 7, priority:**<span style="color:red;">8</span>**
Message received: This is message 3, priority:**<span style="color:red;">6</span>**
Message received: This is message 2, priority:**<span style="color:red;">4</span>**
Message received: This is message 4, priority:**<span style="color:red;">2</span>**
Message received: This is message 9, priority:**<span style="color:red;">0</span>**
...</pre>

Les messages ont été réordonnés par le provider JMS et les messages ont donc été consommés par ordre de priorité.

# Conclusion

La priorité des messages est soit spécifiée dans le [MessageProducer](http://download.oracle.com/javaee/6/api/javax/jms/MessageProducer.html) ou bien comme paramètre de la méthode [send](http://download.oracle.com/javaee/6/api/javax/jms/MessageProducer.html#send(javax.jms.Destination, javax.jms.Message, int, int, long)).

L'erreur fréquente est de spécifier la priorité dans l'objet [Message](http://download.oracle.com/javaee/6/api/javax/jms/Message.html). La méthode [setJMSPriority](http://download.oracle.com/javaee/6/api/javax/jms/Message.html#setJMSPriority(int)) de la classe [Message](http://download.oracle.com/javaee/6/api/javax/jms/Message.html) est appelée par le provider JMS pour définir la priorité du message à envoyer dans la file de messages.

[sourcecode language="java"]

      // Correct

      producer.send(message, DeliveryMode.PERSISTENT, priority, Message.DEFAULT_TIME_TO_LIVE);

      // ou bien

      producer.setJMSPriority(priority);

      producer.send(message);

      // Incorrect

      message.setJMSPriority(priority);

      producer.send(message);

[/sourcecode]

# Références

*   [Code source de l'exemple sur Google Code](http://code.google.com/p/vince/source/browse/#svn%2Ftrunk%2Fmessaging%2Fproducer)
*   [Apache ActiveMQ](http://activemq.apache.org)
*   [ActiveMQ JNDI Support](http://activemq.apache.org/jndi-support.html)
*   [Maven2 ActiveMQ Broker Plugin](http://activemq.apache.org/maven2-activemq-broker-plugin.html)
*   [Playing with ActiveMQ using Maven](http://pookey.co.uk/wordpress/archives/74-playing-with-activemq-using-maven)
*   [EAI Patterns: Resequencer](http://www.eaipatterns.com/Resequencer.html)

