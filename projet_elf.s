;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;nasm -f elf64 -o programme.o projet_elf.s && ld -o programme programme.o

; section pour les constantes
section .data
    filename db 'new_elf', 0  ; Nom du fichier
    Elf_header_struct_size equ 64

    not_elf db 'The binary is not an ELF file', 0xA, 0  ; Erreur type elf
    not_elf_len equ $ - not_elf
    is_elf db 'The binary is an ELF', 0xA, 0  ; Success type elf
    is_elf_len equ $ - is_elf
    is_directory db 'This file is a directory', 0xA, 0  ; Erreur type fichier (dossier)
    is_directory_len equ $ - is_directory
    is_not_directory db 'The file is not a directory', 0xA, 0  ; Success type fichier (n'est pas un dossier)
    is_not_directory_len equ $ - is_not_directory

    error_open db 'Error opening file', 0xA, 0   ; Message d'erreur lors de l'ouverture
    error_open_len equ $ - error_open  ; Longueur de la chaine
    error_stat db 'Error when calling stat', 0xA, 0   ; Message d'erreur lors de l'appel de stat
    error_stat_len equ $ - error_stat
    error_parse db 'Error when parsing the file', 0xA, 0 ; Message d'erreur du parsing
    error_parse_len equ $ - error_parse

    struc Elf_header_struct
        .e_ident: resb 16
        .e_type: resb 2
        .e_machine: resb 2
        .e_version: resb 4
        .e_entry: resb 8
        .e_phoff: resb 8
        .e_shoff: resb 8
        .e_flags: resb 4
        .e_ehsize: resb 2
        .e_phentsize: resb 2
        .e_phnum: resb 2
        .e_shentsize: resb 2
        .e_shnum: resb 2
        .e_shstrndx: resb 2
    endstruc

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; section pour les variables
section .bss
    stat_buffer resb 144 ; 144 = buffer typique pour stat en x86_64
    elf_header resb Elf_header_struct_size ; instance de elf_header_struct (à remplir avec les infos du header elf)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; section pour le code
section .text
global _start

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Main
_start:
    call cmp_stat_directory
    call open_file
    call read_file
    ;call print_buffer
    call cmp_header_elf
    jmp exit_program 

; Ouvrir le fichier
open_file:
    mov rax, 2                    ; numéro de syscall pour open
    mov rdi, filename             ; pointeur vers le nom du fichier
    mov rsi, 0                    ; flags : mode lecture seule
    xor rdx, rdx                  ; mode : non utilisé pour la lecture seule
    syscall                      

    ; Vérifie si le fichier a été ouvert avec succès
    cmp rax, 0
    jl open_error                 ; Si la valeur de retour < 0, c'est une erreur
    mov rdi, rax                  ; Sauvegarde le descripteur de fichier dans rdi
    ret

    ; Afficher le message d'erreur si on a pas pu ouvrir le fichier
    open_error:
        mov rax, 1                    ; syscall pour écrire
        mov rdi, 1                    ; descripteur de fichier : stdout
        mov rsi, error_open       ; pointeur vers le message d'erreur
        mov rdx, error_open_len            ; longueur du message d'erreur
        syscall
        jmp exit_program                         

; Lire les premiers octets du fichier
read_file:
    ; rdi = fd (filename)
    mov rax, 0                    ; syscall pour lire
    mov rsi, elf_header               ; buffer pour stocker les octets
    mov rdx, Elf_header_struct_size                 ; nombre d'octets à lire
    syscall                    
    ret

    ; Afficher le buffer
    print_buffer:
        mov rax, 1 ; syscall pour écrire
        mov rdi, 1 ; descripteur de fichier : stdout
        mov rsi, elf_header ; rsi = buffer (la valeur à écrire)
        mov rdx, 512; rdx = 4 (la taille du buffer)
        syscall
        ret

; Regarder si le fichier est un elf (4 premiers bytes = .ELF)
cmp_header_elf:

    mov eax, dword [elf_header] ; début de la structure = .ELF
    cmp eax,  0x464c457f ;.ELF en hexa (little endian)
    je print_success_equal ; si égal

    ;sinon
    print_not_equal:
    mov rax, 1 ; syscall pour écrire
    mov rdi, 1 ; descripteur de fichier : stdout
    mov rsi, not_elf; rsi = buffer (la valeur à écrire)
    mov rdx, not_elf_len ;(la taille du buffer)
    syscall
    jmp exit_program

print_success_equal:
    mov rax, 1 ; syscall pour écrire
    mov rdi, 1 ; descripteur de fichier : stdout
    mov rsi, is_elf; rsi = buffer (la valeur à écrire)
    mov rdx, is_elf_len ; (la taille du buffer)
    syscall
    ret

cmp_stat_directory:
    mov rax, 4 ; syscall pour stat
    mov rdi, filename ; pointeur vers le nom du fichier
    mov rsi, stat_buffer ; buffer pour stocker la valeur de stat
    syscall

    ; test si stat a fonctionné
    test rax, rax
    js stat_error 

    ; Si pas d'erreurs
    mov eax, [stat_buffer + 24]  ; on tronque pour se placer à l'endroit st_mode (le type du fichier)
    and eax, 0xF000     ; On garde que les 4 bits qui indiquent le type, on met le reste à 0
    cmp eax, 0x4000     ; Compare avec la valeur de base d'un dossier
    je if_directory

    if_not_directory:
        mov rax, 1 ; syscall pour écrire
        mov rdi, 1 ; descripteur de fichier : stdout
        mov rsi, is_not_directory; rsi = la valeur à écrire
        mov rdx, is_not_directory_len ; la taille du buffer
        syscall
        ret

    if_directory:
        mov rax, 1 ; syscall pour écrire
        mov rdi, 1 ; descripteur de fichier : stdout
        mov rsi, is_directory; rsi = la valeur à écrire
        mov rdx, is_directory_len ; la taille du buffer
        syscall
        jmp exit_program

    stat_error:          
        mov rax, 1                    ; syscall pour écrire
        mov rdi, 1                    ; descripteur de fichier : stdout
        mov rsi, error_stat       ; pointeur vers le message d'erreur
        mov rdx, error_stat_len            ; longueur du message d'erreur
        syscall  
        jmp exit_program


; Terminer le programme
exit_program:
    ; Fermer le fichier
    mov rax, 3 ; syscall pour fermer
    syscall

    ; Exit
    mov rax, 60                   ; syscall pour exit
    xor rdi, rdi                  ; statut : 0
    syscall
    
