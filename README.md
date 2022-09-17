<a name="readme-top"></a>

<!-- PROJECT SHIELDS -->

![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
<br />
![Lines of code](https://img.shields.io/tokei/lines/github/GuardianLabs/p2plib-dart?style=flat)
<br />



<h3 align="center">P2Plib Dart</h3>
P2Plib is a minimalistic library for peer-to-peer communication over UDP. Key features:

 - written in pure Dart; 
 - no legacy, the project is simple and self-sufficient.

## Installation
Clone the project:
```
git clone git@github.com:GuardianLabs/p2plib-dart.git
```

## Usage
The main entity is the Router - and it also serves as the entry point for the incoming packets. The Router is assigned handlers, each of which:

 - subscribes to its own type of message (topic);
 - defines how to react to the incoming message (e.g. invoke a callback).
 
Peers are identified by 64-byte public keys: a 32-byte encryption key + a 32-byte public key for signing.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

 ### Basic Handlers
 - EchoHandler, similar to ping;
 - BootstrapHandler, used to introduce peers through the server (_server code is given in the examples_).
 
 > **Note:**  To create a custom handler, implement the TopicHandler interface. 
 
### To use bootstrap server

The peers are introduced to each other through the bootstrap server accessed by pre-defined ip-port tuple. If you want to run your own bootstrap service, you can run it in the Docker container as follows:

```
docker build -t p2pbootstrap -f docker/Dockerfile .
docker-compose -f docker/docker-compose.yml up -d bootstrap
```
### Usage examples

You can see an example of using this library in practice in our project: 
https://github.com/GuardianLabs/guardian-keyper

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Contributing
Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make P2Plib better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- CONTACTS -->
## Contacts
* If you want to report a bug, open an Issue
* If you have a general question or a suggestion, create a GitHub Discussion

<p align="right">(<a href="#readme-top">back to top</a>)</p>
 
