# ToChatZig
Zig ToChat (previously made in Go)  
It is a multi thread tcp server/client

# Compile
To compile simply use those two commands:  
`zig build-exe server.zig`  
`zig build-exe client.zig`  


TODO:

- [ ] Asymetric encryption
  - [ ] Gen keys, server allows to copy/paste public key to share w client
  - [ ] Client ask for a preshared public key
- [ ] Merge Client and Server in One soft
  - [ ] Parse arguments
  - [ ] Menu for what wasnt in the arguments
