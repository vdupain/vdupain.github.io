---
layout: post
title: Gestion des priorités des messages JMS
date: 2011-03-25
comments: true
categories: developpement
---

Ce Quick Start Guide JMS a pour but de montrer simplement comment poster des messages dans une file JMS et de les consommer par ordre de priorité comme illustré par le schéma suivant:

[![](/assets/resequencer.gif "Resequencer")](http://www.eaipatterns.com/Resequencer.html)

Cet exemple a été réalisé et testé dans l'environnement suivant:

* Java 6
* Maven 2.2.1 et 3.0.2
* Provider JMS ActiveMQ 5.4.2: la priorité des message est fonctionnelle depuis la version [5.4.0](http://activemq.apache.org/new-features-in-54.html)
* Provider JMS JBoss Messaging 1.4.0.x (demande à uploader certaines librairies dans son repo local maven car non disponibles dans le repo central et le [repo JBoss](http://repository.jboss.org/maven2/))

## Le Développement

### Création du projet avec Maven

Tout d'abord, nous allons créer un projet **maven** avec le plugin **archetype**:

```
$ mvn --batch-mode archetype:generate -DarchetypeArtifactId=maven-archetype-quickstart -DgroupId=com.mycompany.messaging -DartifactId=messaging -Dversion=1.0.0
```

#### Configuration du pom.xml

Il faut ensuite modifier le fichier **pom.xml** pour:

*   ajouter les dépendances vers les librairies JMS et le provider JMS ActiveMQ
*   ajouter la configuration du plugin ActiveMQ pour lancer le provider JMS

```xml
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/maven-v4_0_0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.mycompany.messaging</groupId>
  <artifactId>messaging</artifactId>
  <packaging>jar</packaging>
  <version>1.0.0</version>
  <name>messaging</name>
  <url>http://maven.apache.org</url>
  <dependencies>
    <dependency>
      <groupId>junit</groupId>
      <artifactId>junit</artifactId>
      <version>3.8.1</version>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>javax.jms</groupId>
      <artifactId>jms-api</artifactId>
      <version>1.1-rev-1</version>
    </dependency>
    <dependency>
      <groupId>org.apache.activemq</groupId>
      <artifactId>activemq-core</artifactId>
      <version>5.5.1</version>
    </dependency>
    <dependency>
      <groupId>org.slf4j</groupId>
      <artifactId>slf4j-api</artifactId>
      <version>1.6.1</version>
    </dependency>
    <dependency>
      <groupId>ch.qos.logback</groupId>
      <artifactId>logback-classic</artifactId>
      <version>0.9.28</version>
    </dependency>
  </dependencies>
  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.activemq.tooling</groupId>
        <artifactId>maven-activemq-plugin</artifactId>
        <version>5.4.2</version>
        <configuration>
          <configUri>xbean:file:./conf/activemq.xml</configUri>
          <fork>false</fork>
          <systemProperties>
            <property>
              <name>javax.net.ssl.keyStorePassword</name>
              <value>password</value>
            </property>
            <property>
              <name>org.apache.activemq.default.directory.prefix</name>
              <value>./target/</value>
            </property>
          </systemProperties>
        </configuration>
      </plugin>
    </plugins>
  </build>
</project>
```
#### Le plugin maven-activemq-plugin

ActiveMQ fournit un plugin maven 2 **maven-activemq-plugin** pour démarrer facilement un provider JMS. La configuration de ce plugin étant déjà faite dans le fichier pom.xml, il reste à créer un fichier de configuration **activemq.xml** dans un répertoire **conf** à la racine de notre projet.

Créer un fichier conf/activemq.xml:

```xml
<?xml version="1.0"?>
<beans xmlns="http://www.springframework.org/schema/beans" xmlns:amq="http://activemq.apache.org/schema/core"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://www.springframework.org/schema/beans
  http://www.springframework.org/schema/beans/spring-beans-2.0.xsd
  http://activemq.apache.org/schema/core
  http://activemq.apache.org/schema/core/activemq-core.xsd
  ">
  <broker xmlns="http://activemq.apache.org/schema/core" brokerName="localhost" dataDirectory="./target/data">
    <!-- The transport connectors ActiveMQ will listen to -->
    <transportConnectors>
      <transportConnector name="openwire" uri="tcp://localhost:61616" />
    </transportConnectors>
  </broker>
</beans>
```

#### Support JNDI

Il est nécessaire de récupérer certaines informations depuis un contexte JNDI pour créer une connexion au provider JMS ActiveMQ.

Créer un fichier **jndi.properties** dans le répertoire **src/main/resources**

```
java.naming.factory.initial=org.apache.activemq.jndi.ActiveMQInitialContextFactory
java.naming.provider.url=tcp://localhost:61616
queue.queue1 = example.queue1
```

Ensuite, nous allons créer un Producer et un Consumer pour poster et consommer les messages.

### Le Producer

Nous allons créer un Producer qui envoie des messages à la file de messages. Le Producer prendra en paramètre:

*   la file de messages de destination
*   le nombre de messages à envoyer. Si non renseigné, un seul message sera envoyé
*   la priorité des messages. Si non renseignée, la priorité est aléatoire (entre 0 et 9)

Créer une classe **Producer** dans le répertoire **src/main/java/com/mycompany/messaging**:

```java
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

		if ((args.length < 1) || (args.length > 3)) {
			System.out
					.println("Usage: java Producer <destination-name> [<number-of-messages>] [<priority-of-messages>]");
			System.exit(1);
		}
		destinationName = args[0];
		System.out.println("Destination name is " + destinationName);
		if (args.length >= 2) {
			numMsgs = Integer.valueOf(args[1]);
		}
		if (args.length == 3) {
			priority = Integer.valueOf(args[2]);
		}
		try {
			jndiContext = new InitialContext();
			connectionFactory = (ConnectionFactory) jndiContext
					.lookup("ConnectionFactory");
			destination = (Destination) jndiContext.lookup(destinationName);
		} catch (NamingException e) {
			e.printStackTrace();
			System.exit(1);
		}

		try {
			connection = connectionFactory.createConnection();
			session = connection.createSession(false, Session.AUTO_ACKNOWLEDGE);
			producer = session.createProducer(destination);
			TextMessage message = session.createTextMessage();
			for (int i = 0; i < numMsgs; i++) {
				message.setText("This is message " + i);
				int p = priority;
				if (priority == -1) {
					p = (int) (Math.random() * 10);
				}
				System.out.println("Sending message: " + message.getText()
						+ " with priority: " + p);
				producer.send(message, DeliveryMode.PERSISTENT, p,
						Message.DEFAULT_TIME_TO_LIVE);
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
```

### Le Consumer

Nous allons créer un Consumer qui consomme les messages de la file. Le Consumer prendra en paramètre:

* la file de messages

Créer une classe **Consumer** dans le répertoire **src/main/java/com/mycompany/messaging**:

```java
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

		if ((args.length < 1) || (args.length > 1)) {
			System.out.println("Usage: java Consumer <destination-name>");
			System.exit(1);
		}
		destinationName = args[0];
		System.out.println("Destination name is " + destinationName);

		try {
			jndiContext = new InitialContext();
			connectionFactory = (ConnectionFactory) jndiContext
					.lookup("ConnectionFactory");
			destination = (Destination) jndiContext.lookup(destinationName);
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
					System.out.println("waiting...");
					continue;
				}
				if (message instanceof TextMessage) {
					TextMessage txtMessage = (TextMessage) message;
					System.out.println("Message received: "
							+ txtMessage.getText() + ", priority:"
							+ txtMessage.getJMSPriority());
				} else {
					System.out.println("Invalid message received.");
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
```

## Le Build et le Run

### Run du Prodiver JMS

Pour lancer le provider JMS ActiveMQ, il suffit d'exécuter la commande maven suivante:

```
$ mvn activemq:run
...
INFO: ActiveMQ JMS Message Broker (localhost, ID:GF106903-1477-1301046394468-0:1) started
```

Le provider JMS ActiveMQ est démarré!

### Envoi des messages

Créer 10 messages de priorité aléatoire (0 à 9) et les poster dans la file de messages "queue1":

```
$ mvn clean compile exec:java -Dexec.mainClass=com.mycompany.messaging.Producer -Dexec.args="queue1 10"
...
Sending message: This is message 0 with priority: 8
Sending message: This is message 1 with priority: 9
Sending message: This is message 2 with priority: 4
Sending message: This is message 3 with priority: 6
Sending message: This is message 4 with priority: 2
Sending message: This is message 5 with priority: 8
Sending message: This is message 6 with priority: 8
Sending message: This is message 7 with priority: 8
Sending message: This is message 8 with priority: 9
Sending message: This is message 9 with priority: 9
...
```

### Consommation des messages

Consommer les messages depuis la file de message "queue1":

```
$ mvn clean compile exec:java -Dexec.mainClass=com.mycompany.messaging.Consumer -Dexec.args="queue1"
...
Message received: This is message 1, priority:9
Message received: This is message 8, priority:9
Message received: This is message 0, priority:8
Message received: This is message 5, priority:8
Message received: This is message 6, priority:8
Message received: This is message 7, priority:8
Message received: This is message 3, priority:6
Message received: This is message 2, priority:4
Message received: This is message 4, priority:2
Message received: This is message 9, priority:0
...
```

Les messages ont été réordonnés par le provider JMS et les messages ont donc été consommés par ordre de priorité.

## Conclusion

La priorité des messages est soit spécifiée dans le [MessageProducer](http://download.oracle.com/javaee/6/api/javax/jms/MessageProducer.html) ou bien comme paramètre de la méthode [send](http://download.oracle.com/javaee/6/api/javax/jms/MessageProducer.html#send(javax.jms.Destination, javax.jms.Message, int, int, long)).

L'erreur fréquente est de spécifier la priorité dans l'objet [Message](http://download.oracle.com/javaee/6/api/javax/jms/Message.html). La méthode [setJMSPriority](http://download.oracle.com/javaee/6/api/javax/jms/Message.html#setJMSPriority(int)) de la classe [Message](http://download.oracle.com/javaee/6/api/javax/jms/Message.html) est appelée par le provider JMS pour définir la priorité du message à envoyer dans la file de messages.

```java
      // correct
      producer.send(message, DeliveryMode.PERSISTENT, priority, Message.DEFAULT_TIME_TO_LIVE);

      // ou bien
      producer.setJMSPriority(priority);
      producer.send(message);

      // incorrect
      message.setJMSPriority(priority);
      producer.send(message);
```

## Références

* [Code source sur GitHub](https://github.com/vdupain/jms/tree/master/messaging)
* [Apache ActiveMQ](http://activemq.apache.org)
* [ActiveMQ JNDI Support](http://activemq.apache.org/jndi-support.html)
* [Maven2 ActiveMQ Broker Plugin](http://activemq.apache.org/maven2-activemq-broker-plugin.html)
* [Playing with ActiveMQ using Maven](http://pookey.co.uk/wordpress/archives/74-playing-with-activemq-using-maven)
* [EAI Patterns: Resequencer](http://www.eaipatterns.com/Resequencer.html)

