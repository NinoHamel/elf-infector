# 🦠 Projet de Virus Informatique - Infecteur de Binaire ELF

## 📝 Introduction
Ce projet implémente un virus informatique simple qui modifie des binaires ELF pour y injecter un payload. Le code est écrit en assembleur x86_64 et cible les systèmes Linux.

## 🛠️ ️Pour compile et lancer le programme :

```
nasm -f elf64 -o programme.o projet_elf.s && ld -o programme programme.o
```

Pour choisir le fichier cible il faut changer ls avec le nom de votre fichier dans la ligne

```
filename db 'ls', 0
```

## 📊 Étapes de développement 
### 🔍 Découverte et premiers tests 

Pendant la première journée où on avait du temps pour avancer sur le projet, je me suis familiarisé avec le code assembleur et la [table des syscall](https://syscalls.w3challs.com/?arch=x86_64). J'ai pu avancer rapidement pour faire un petit programme qui ouvre un binaire (je me suis basé sur **ls** pour les tests), le lit, puis le ferme et termine le programme sans faire d'erreur de segmentation.

J'ai aussi eu le temps de vérifier si le fichier était dans le format ELF. Pour ça, j'ai juste pris le buffer du fichier ouvert et regardé si le nombre magique était bien ```0x464c457f``` (.ELF en little endian).

J'ai aussi essayé de mettre un maximum de debug dans le programme pour afficher les étapes ou les potentielles erreurs que celui-ci pouvait avoir. J'ai voulu parser le header de l'ELF dans une structure mais sans succès : je n'arrivais à travailler qu'avec le buffer. En utilisant **pwndbg**, j'avais soit rien dans ma structure, soit je n'arrivais pas à accéder aux valeurs dedans.

### ⚙️ Améliorations et correctionss

Plusieurs semaines plus tard, j'ai continué le projet en rajoutant un appel syscall avec ```stat``` pour tester si l'input était un dossier ou non. Avec ```stat```, j'ai réussi à débloquer mon problème et à mettre le buffer dans ma structure ```Elf_Header```, ce qui m'a permis d'avoir facilement accès à des valeurs comme le nombre de **Program Headers** ou le **point d'entrée** du programme par exemple.

### 🧩 Recherche du segment PT_NOTE

La recherche du PT_NOTE a représenté un grand avancement dans le projet. Cela m'a demandé de comprendre beaucoup d'aspects du langage assembleur. Jusqu'ici, j'avais principalement tout fait avec mes connaissances en avançant petit pas par petit pas, mais pour cette partie, j'ai dû chercher des instructions plus complexes sur comment faire des boucles efficacement ou l'utilisation des crochets pour faire la différence entre adresse et valeur.

Pour les boucles, j'ai testé plusieurs méthodes : l'instruction ```loop```, qui marche en décrémentant ```rcx```, et la version avec une variable que je gère moi-même dans une **pile** (j'aurais pu prendre un autre registre, mais ça m'a permis d'expérimenter avec la pile).

Pour trouver le **PT_NOTE**, je parcours tous les **Program Headers** et je regarde si le type équivaut à **4** au début de chaque header. Si je trouve un **PT_NOTE**, je sauvegarde l'adresse pour plus tard, sinon je continue la boucle. Au début, je ne comprenais pas trop les **Program Headers** et j'avais souvent des erreurs de segmentation parce que je parcourais des endroits auxquels je n'avais pas accès. Mais en regardant mieux les schémas du cours et sur internet, j'ai corrigé avec le bon espacement (**56 octets**).

### ⚡ Infection et défis rencontréss
La partie la plus complexe du projet concernait la transformation du **PT_NOTE** en **PT_LOAD** :

Pour cette partie, je me suis inspiré de ce [Github](https://github.com/guitmz/midrashim)et de cet [article](https://www.symbolcrash.com/2019/03/27/pt_note-to-pt_load-injection-in-elf/). Je n’ai pas énormément compris comment fonctionnait le code de guitmz, mais cela m’a permis de voir un peu quelle forme devait avoir mon programme. L'article par contre m’a surtout aidé à comprendre ce que je devais faire.

J’ai essayé de procéder étape par étape, mais lorsque je voulais modifier le type du **PT_NOTE** de 4 à 1, cela ne fonctionnait pas. Je ne sais toujours pas pourquoi ça ne marchait pas : peut-être qu’il y a une protection si le **PT_LOAD** n'est pas conforme. En tout cas, simplement changer le type ne suffisait pas pour transformer le type NOTE en LOAD.

J'ai passé beaucoup de temps à debugger, jusqu’à essayer de modifier d’autres informations (comme les flags, p_vaddr et p_offset) pour qu’il se transforme enfin en **PT_LOAD**. J’ai utilisé **readelf**, **objdump** et **hexdump** pour vérifier les résultats, en complément des messages de succès de mon code.

Ensuite, il a fallu que je trouve un endroit pour placer mon payload. Pour cela, je boucle à nouveau dans les Program Headers pour trouver le dernier segment **PT_LOAD** et le remplacer avec les informations voulues (nouveau point d'entrée, le payload, etc.).

À ce moment-là, j'avais terminé la partie **obligatoire** du projet, mais je voulais quand même avoir au moins un binaire fonctionnel une fois infecté, capable d'afficher un artwork stylé. Malheureusement, je n'y suis pas arrivé. Après de nombreuses heures de debug, j'ai au moins réussi à "aligner" mon payload plus ou moins "correctement", car je suis passé d'une erreur de **segmentation** à une erreur de **bus**. J'interprète cette erreur comme une progression, car le programme n'essaie plus d'accéder à une zone inaccessible, mais seulement à une zone mal alignée.

### 📘 Ajout du README

Pour terminer le projet, j'ai ajouté des commentaires là où le code en avait besoin et j'ai créé ce README pour expliquer mon travail.

### 🎯 Résultat
Ce que le programme fait :

- Analyse un fichier précis (à configurer dans le code)
- Vérifie s'il s'agit d'un dossier puis s'il s'agit d'un fichier ELF 
- Injecte un payload qui devrait afficher **"This file is infected!"** lors de l'exécution du binaire
- Endommage le binaire et provoque une erreur de bus lors de son exécution

### ⚠️ Note
Ce projet a été réalisé dans un cadre éducatif pour comprendre le format ELF et l'assembleur x86_64.