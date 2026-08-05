# Arch Linux / Hyprland dotfiles

Repositorio reproducible para desplegar un entorno Arch Linux con Hyprland,
GNU Stow, perfiles de hardware y manifiestos de paquetes separados por
procedencia y finalidad.

Este repositorio no es una copia indiscriminada de `$HOME`. Solo contiene:

- configuraciones seleccionadas;
- manifiestos de paquetes;
- perfiles de hardware;
- scripts de instalación, despliegue y validación;
- documentación;
- recursos visuales no sensibles.

No contiene documentos personales, descargas, claves privadas, tokens,
historiales, cachés ni credenciales.

---

## 1. Objetivos

Los objetivos principales son:

1. Poder reconstruir el entorno en una instalación limpia de Arch Linux.
2. Mantener configuraciones bajo control de versiones.
3. Separar configuración común y configuración específica de cada máquina.
4. Separar paquetes oficiales de paquetes AUR.
5. Evitar enlaces simbólicos manuales difíciles de mantener.
6. Poder validar los dotfiles antes de cerrar sesión o migrar.
7. Mantener el portátil anterior operativo durante las migraciones.
8. Permitir rollback mediante Git, backups y GNU Stow.
9. Documentar explícitamente cómo modificar configuraciones y paquetes.
10. Evitar que información privada termine en un repositorio público.

---

## 2. Estado del repositorio

La rama estable debe ser `main`.

Los cambios importantes se desarrollan siempre en ramas separadas. Ejemplos:

```text
refactor/package-profiles
refactor/waybar-single-config
refactor/stow-layout
refactor/finalize-repository
feature/new-waybar-module
fix/hyprland-monitor-profile
```

Una rama no contiene solamente los archivos modificados. Cada rama representa
un estado completo del repositorio.

Para comparar una rama con `main`:

```bash
git diff --stat main...HEAD
git diff --name-status main...HEAD
git diff main...HEAD
```

---

## 3. Ubicación esperada

El repositorio debe clonarse exactamente en:

```text
~/dotfiles
```

Varias rutas internas y scripts presuponen esa ubicación.

Clonado:

```bash
git clone https://github.com/joansr27/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
```

---

## 4. Estructura

```text
dotfiles/
├── configs/
│   ├── hypr/
│   │   └── .config/hypr/
│   ├── kitty/
│   │   └── .config/kitty/
│   ├── nvim/
│   │   └── .config/nvim/
│   ├── waybar/
│   │   └── .config/waybar/
│   ├── wofi/
│   │   └── .config/wofi/
│   └── xdg-user-dirs/
│       └── .config/
├── docs/
├── install/
├── packages/
│   ├── common/
│   ├── features/
│   ├── hardware/
│   ├── profiles/
│   └── aur/
├── scripts/
├── wallpapers/
├── .gitignore
└── README.md
```

### `configs/`

Contiene paquetes GNU Stow.

Cada paquete reproduce rutas relativas a `$HOME`.

Ejemplo:

```text
configs/hypr/.config/hypr/hyprland.conf
```

se despliega como:

```text
~/.config/hypr/hyprland.conf
```

### `packages/`

Es la única fuente de verdad para paquetes.

No debe existir una lista monolítica `packages.txt`.

### `install/`

Contiene el instalador de alto nivel.

### `scripts/`

Contiene herramientas pequeñas, comprobables y reutilizables.

### `docs/`

Contiene documentación histórica o técnica complementaria.

### `wallpapers/`

Contiene recursos visuales compartidos por Hyprpaper e Hyprlock.

---

## 5. GNU Stow

GNU Stow crea y mantiene los enlaces entre el repositorio y `$HOME`.

Directorio Stow:

```text
~/dotfiles/configs
```

Destino:

```text
$HOME
```

Ejemplo manual:

```bash
stow \
    --dir="$HOME/dotfiles/configs" \
    --target="$HOME" \
    hypr
```

### Simular antes de aplicar

```bash
./scripts/stow-preflight.sh
```

Para un único paquete:

```bash
stow \
    --simulate \
    --verbose=2 \
    --dir="$HOME/dotfiles/configs" \
    --target="$HOME" \
    waybar
```

### Aplicar o actualizar

```bash
./scripts/stow-config.sh waybar
```

### Retirar enlaces

```bash
./scripts/unstow-config.sh waybar
```

`unstow` elimina enlaces. No debe borrar los archivos reales almacenados dentro
del repositorio.

### Conflictos

Un conflicto como:

```text
existing target is not owned by stow
```

significa que ya existe un archivo o directorio real en el destino.

No debe utilizarse `stow --adopt` sin inspeccionar cuidadosamente el resultado.

Procedimiento seguro:

```bash
backup="$HOME/dotfiles-backup/manual-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"

cp -aL "$HOME/.config/waybar" "$backup/waybar"

mv "$HOME/.config/waybar" "$backup/waybar-original"

./scripts/stow-config.sh waybar
```

---

## 6. Perfiles de paquetes

Los perfiles oficiales se encuentran en:

```text
packages/profiles/
```

Perfiles actuales:

```text
amd-current
omen
```

Resolver un perfil:

```bash
./scripts/resolve-packages.sh amd-current
./scripts/resolve-packages.sh omen
```

Los perfiles AUR están en:

```text
packages/aur/profiles/
```

Resolverlos:

```bash
./scripts/resolve-aur-packages.sh amd-current
./scripts/resolve-aur-packages.sh omen
```

### Categorías

`packages/common/`:

- sistema base;
- red;
- audio;
- Hyprland;
- Bluetooth;
- herramientas CLI;
- almacenamiento;
- aplicaciones;
- impresión;
- mantenimiento;
- fuentes.

`packages/hardware/`:

- microcódigo;
- Mesa/Vulkan;
- Intel;
- AMD;
- NVIDIA;
- utilidades dependientes del hardware.

`packages/features/`:

- Python científico;
- herramientas de diagnóstico;
- acceso remoto;
- futuras características opcionales.

`packages/aur/`:

- aplicaciones no distribuidas en repositorios oficiales;
- software propietario;
- Sunshine;
- herramientas obtenidas mediante AUR.

---

## 7. Perfiles de máquina de Hyprland

Los monitores no se definen directamente en la configuración común.

Perfiles:

```text
~/.config/hypr/machines/amd-current.conf
~/.config/hypr/machines/omen.conf
```

El perfil activo se selecciona mediante:

```text
~/.config/hypr/machine.conf
```

Ese archivo es un enlace local no versionado.

Seleccionar AMD:

```bash
cd "$HOME/dotfiles"
./scripts/select-machine.sh amd-current
```

Seleccionar OMEN:

```bash
cd "$HOME/dotfiles"
./scripts/select-machine.sh omen
```

Comprobar monitores:

```bash
hyprctl monitors all
```

Después de modificar un perfil:

```bash
hyprctl reload
hyprctl configerrors
```

Nunca debe suponerse que dos ordenadores usan los mismos nombres `eDP-*`,
`HDMI-A-*` o `DP-*`.

---

## 8. Lector de documentos

El lector único es Okular.

Motivos:

- lectura general;
- PDFs científicos;
- anotaciones y resaltado;
- formularios;
- firmas digitales;
- miniaturas e índice;
- selección de texto y regiones;
- impresión;
- múltiples formatos.

Configurar como predeterminado:

```bash
xdg-mime default org.kde.okular.desktop application/pdf
```

Comprobar:

```bash
xdg-mime query default application/pdf
```

Abrir mediante asociación MIME:

```bash
xdg-open documento.pdf
```

Las preferencias generadas automáticamente por Okular no se versionan hasta
que exista una decisión explícita sobre cuáles son realmente portables.

---

## 9. Migración a un ordenador nuevo

### 9.1. Antes de empezar

Guardar:

- documentos personales;
- claves SSH;
- claves GPG;
- códigos de recuperación;
- configuraciones no versionadas;
- lista de discos y particiones;
- configuración de bootloader;
- información sobre Btrfs;
- inventario de hardware.

Comandos útiles:

```bash
lsblk -f
lspci -nnk
lsusb
findmnt
sudo btrfs subvolume list /
```

No publicar la salida completa si contiene información sensible.

### 9.2. Instalar Arch Linux

Completar una instalación base funcional antes de usar este repositorio.

Debe existir:

- usuario no root;
- sudo;
- conexión de red;
- sistema arrancable;
- `git`;
- repositorios Pacman configurados.

### 9.3. Habilitar Multilib

Los perfiles contienen paquetes `lib32-*`.

Editar:

```bash
sudoedit /etc/pacman.conf
```

Descomentar:

```ini
[multilib]
Include = /etc/pacman.d/mirrorlist
```

Actualizar:

```bash
sudo pacman -Syu
```

Verificar:

```bash
pacman-conf --repo-list | grep -x multilib
```

### 9.4. Clonar

```bash
sudo pacman -S --needed git

git clone \
    https://github.com/joansr27/dotfiles.git \
    "$HOME/dotfiles"

cd "$HOME/dotfiles"
```

Usar la rama estable:

```bash
git switch main
git pull --ff-only
```

### 9.5. Revisar antes de instalar

```bash
git status
git log --oneline --decorate -10

./scripts/resolve-packages.sh omen
./scripts/resolve-aur-packages.sh omen
```

### 9.6. Ejecutar el instalador

Para el OMEN:

```bash
./install/install.sh omen
```

Para el portátil AMD:

```bash
./install/install.sh amd-current
```

El instalador:

1. actualiza Arch;
2. instala paquetes oficiales;
3. instala `yay` cuando falta;
4. instala paquetes AUR;
5. selecciona el perfil de máquina;
6. crea `Desktop` y `Downloads`;
7. valida Stow;
8. despliega configuraciones;
9. configura Okular como lector PDF.

No habilita servicios automáticamente.

### 9.7. Servicios

Revisar uno por uno:

```bash
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth
sudo systemctl enable --now firewalld
sudo systemctl enable --now sddm
```

Estado:

```bash
systemctl status NetworkManager
systemctl status bluetooth
systemctl status firewalld
systemctl status sddm
```

### 9.8. Tailscale

```bash
sudo systemctl enable --now tailscaled
sudo tailscale up
```

Estado:

```bash
tailscale status
```

### 9.9. Sunshine

Primera prueba manual:

```bash
systemctl --user start app-dev.lizardbyte.app.Sunshine
```

Estado:

```bash
systemctl --user status app-dev.lizardbyte.app.Sunshine
```

No exponer Sunshine mediante port forwarding público.

Los scripts manuales son:

```bash
./scripts/remote-on.sh
./scripts/remote-off.sh
```

### 9.10. Detectar monitores

```bash
hyprctl monitors all
```

Editar:

```bash
nvim \
    "$HOME/.config/hypr/machines/omen.conf"
```

Recargar:

```bash
hyprctl reload
hyprctl configerrors
```

### 9.11. Backlight

```bash
ls -l /sys/class/backlight
brightnessctl --list
```

Waybar intenta detectar automáticamente el dispositivo.

### 9.12. Validación

```bash
cd "$HOME/dotfiles"

./scripts/stow-preflight.sh
./scripts/check-desktop-config.sh
./scripts/validate-packages.sh omen

hyprctl configerrors
pgrep -a waybar
pgrep -a hyprpaper
```

Comprobar enlaces rotos relacionados con el repositorio:

```bash
find "$HOME/.config" \
    -xtype l \
    -lname '*dotfiles*' \
    -print
```

---

## 10. Migrar una instalación existente

Nunca mover todas las configuraciones simultáneamente.

### 10.1. Crear backup

```bash
backup="$HOME/dotfiles-backup/existing-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"

cp -aL "$HOME/.config/hypr" "$backup/hypr"
cp -aL "$HOME/.config/waybar" "$backup/waybar"
cp -aL "$HOME/.config/kitty" "$backup/kitty"
```

### 10.2. Desplegar una aplicación cada vez

Ejemplo Waybar:

```bash
stow \
    --simulate \
    --verbose=2 \
    --dir="$HOME/dotfiles/configs" \
    --target="$HOME" \
    waybar
```

Resolver conflictos, aplicar y probar:

```bash
./scripts/stow-config.sh waybar

pkill waybar

waybar \
    -c "$HOME/.config/waybar/config.jsonc" \
    -s "$HOME/.config/waybar/style.css"
```

Continuar con la siguiente aplicación únicamente después de confirmar que la
anterior funciona.

---

## 11. Modificar una configuración

Este es el procedimiento obligatorio para modificar Hyprland, Waybar, Kitty,
Neovim, Wofi u otro paquete Stow.

### 11.1. Actualizar el repositorio

```bash
cd "$HOME/dotfiles"
git switch main
git pull --ff-only
git status
```

### 11.2. Crear una rama

Ejemplo:

```bash
git switch -c feature/waybar-network-tooltip
```

Nunca desarrollar directamente en `main`.

### 11.3. Editar

Como `~/.config` está enlazado al repositorio, puede editarse por cualquiera
de las dos rutas.

Ruta desplegada:

```bash
nvim "$HOME/.config/waybar/config.jsonc"
```

Ruta del repositorio:

```bash
nvim \
    "$HOME/dotfiles/configs/waybar/.config/waybar/config.jsonc"
```

Ambas representan el mismo archivo.

### 11.4. Probar

Waybar:

```bash
pkill waybar

waybar \
    -l debug \
    -c "$HOME/.config/waybar/config.jsonc" \
    -s "$HOME/.config/waybar/style.css"
```

Hyprland:

```bash
hyprctl reload
hyprctl configerrors
```

Kitty:

```bash
kitty --config "$HOME/.config/kitty/kitty.conf"
```

Neovim:

```bash
nvim --headless '+qa'
```

Scripts Bash:

```bash
bash -n ruta/al/script.sh
```

### 11.5. Revisar Git

```bash
cd "$HOME/dotfiles"

git status --short
git diff --check
git diff --stat
git diff
```

### 11.6. Guardar

```bash
git add ruta/modificada
```

Revisar el commit:

```bash
git diff --cached --check
git diff --cached --stat
git diff --cached
```

Crear commit:

```bash
git commit -m "feat: improve Waybar network tooltip"
```

Subir:

```bash
git push -u origin HEAD
```

Después de revisar y probar, integrar en `main`.

---

## 12. Instalar y registrar un paquete nuevo

Un paquete no queda reproducible por el simple hecho de instalarlo.

Debe:

1. instalarse;
2. clasificarse;
3. añadirse al manifiesto correcto;
4. validarse;
5. probarse;
6. registrarse en Git.

### 12.1. Determinar procedencia

Repositorio oficial:

```bash
pacman -Si nombre-paquete
```

AUR:

```bash
yay -Si nombre-paquete
```

No añadir el mismo paquete a ambas categorías.

### 12.2. Crear rama

```bash
cd "$HOME/dotfiles"
git switch main
git pull --ff-only
git switch -c packages/add-nombre-paquete
```

### 12.3. Paquete oficial común

Ejemplo:

```bash
printf '%s\n' nombre-paquete \
    >> packages/common/07-applications.txt

sort -u \
    -o packages/common/07-applications.txt \
    packages/common/07-applications.txt
```

Instalar:

```bash
sudo pacman -S --needed nombre-paquete
```

### 12.4. Paquete específico de hardware

AMD:

```bash
printf '%s\n' nombre-paquete \
    >> packages/hardware/amd-laptop.txt
```

OMEN:

```bash
printf '%s\n' nombre-paquete \
    >> packages/hardware/omen-intel-nvidia.txt
```

Ordenar:

```bash
sort -u -o ARCHIVO ARCHIVO
```

### 12.5. Paquete de una característica

Crear:

```bash
printf '%s\n' nombre-paquete \
    >> packages/features/nombre-caracteristica.txt
```

Añadir la característica al perfil:

```bash
printf '%s\n' \
    'features/nombre-caracteristica.txt' \
    >> packages/profiles/omen.txt
```

### 12.6. Paquete AUR

```bash
printf '%s\n' nombre-paquete \
    >> packages/aur/common.txt

sort -u \
    -o packages/aur/common.txt \
    packages/aur/common.txt

yay -S --needed nombre-paquete
```

### 12.7. Validar

```bash
./scripts/resolve-packages.sh omen
./scripts/resolve-aur-packages.sh omen
./scripts/validate-packages.sh omen
```

Duplicados:

```bash
comm -12 \
    <(./scripts/resolve-packages.sh omen | sort -u) \
    <(./scripts/resolve-aur-packages.sh omen | sort -u)
```

Debe quedar vacío.

### 12.8. Guardar en Git

```bash
git status --short
git diff --check
git diff

git add packages/
git commit -m "packages: add nombre-paquete"
git push -u origin HEAD
```

---

## 13. Eliminar un paquete

Crear rama:

```bash
git switch main
git pull --ff-only
git switch -c packages/remove-nombre-paquete
```

Eliminarlo del manifiesto:

```bash
sed -i \
    '/^nombre-paquete$/d' \
    packages/common/07-applications.txt
```

Desinstalar:

```bash
sudo pacman -Rns nombre-paquete
```

Cuando tenga configuración Stow:

```bash
./scripts/unstow-config.sh nombre
git rm -r configs/nombre
```

Validar y guardar:

```bash
./scripts/validate-packages.sh omen

git add -A
git commit -m "packages: remove nombre-paquete"
git push -u origin HEAD
```

---

## 14. Añadir una nueva configuración a Stow

Supóngase una aplicación llamada `example`.

Estructura deseada:

```text
configs/example/.config/example/
```

Crear backup:

```bash
backup="$HOME/dotfiles-backup/example-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"

cp -aL "$HOME/.config/example" "$backup/example"
```

Copiar al repositorio:

```bash
mkdir -p \
    "$HOME/dotfiles/configs/example/.config"

cp -a \
    "$HOME/.config/example" \
    "$HOME/dotfiles/configs/example/.config/example"
```

Mover temporalmente el destino:

```bash
mv \
    "$HOME/.config/example" \
    "$backup/example-original"
```

Simular:

```bash
stow \
    --simulate \
    --verbose=2 \
    --dir="$HOME/dotfiles/configs" \
    --target="$HOME" \
    example
```

Aplicar:

```bash
./scripts/stow-config.sh example
```

Probar la aplicación antes de crear el commit.

---

## 15. Git y seguridad

El repositorio es público.

Nunca añadir:

```text
~/.ssh/
~/.gnupg/
.env
.env.*
tokens
cookies
contraseñas
claves privadas
credenciales de API
perfiles de navegador
historiales
bases de datos personales
```

Antes de hacer commit:

```bash
git status --short
git diff --cached
```

Buscar nombres sospechosos:

```bash
git diff --cached --name-only |
    grep -Ei \
    'secret|token|credential|password|private|\.env|id_rsa|id_ed25519'
```

Buscar contenido sospechoso:

```bash
git diff --cached |
    grep -Ei \
    'api[_-]?key|access[_-]?token|client[_-]?secret|password'
```

Una coincidencia no siempre es una credencial, pero debe revisarse.

---

## 16. Rollback

### Deshacer cambios no guardados de un archivo

```bash
git restore ruta/al/archivo
```

### Deshacer cambios preparados

```bash
git restore --staged ruta/al/archivo
```

### Restaurar desde otra rama

```bash
git show main:ruta/al/archivo > ruta/al/archivo
```

### Revertir un commit publicado

```bash
git revert SHA_DEL_COMMIT
git push
```

Evitar reescribir el historial público mediante `git push --force`.

### Retirar temporalmente una configuración

```bash
./scripts/unstow-config.sh waybar
```

### Volver a desplegarla

```bash
./scripts/stow-config.sh waybar
```

---

## 17. Diagnóstico

### Hyprland parece usar valores predeterminados

Comprobar:

```bash
ls -ld "$HOME/.config/hypr"
readlink -f "$HOME/.config/hypr"

test -r "$HOME/.config/hypr/hyprland.conf"
```

Después:

```bash
hyprctl reload
hyprctl configerrors
```

### Waybar no arranca

```bash
waybar \
    -l debug \
    -c "$HOME/.config/waybar/config.jsonc" \
    -s "$HOME/.config/waybar/style.css"
```

### Enlaces rotos del repositorio

```bash
find "$HOME/.config" \
    -xtype l \
    -lname '*dotfiles*' \
    -print
```

Los enlaces `SingletonLock` o `SingletonCookie` de Chrome no pertenecen a
Stow y no deben usarse para diagnosticar el repositorio.

### Revisar paquetes Stow

```bash
./scripts/stow-preflight.sh
```

### Revisar escritorio

```bash
./scripts/check-desktop-config.sh
```

### Revisar paquetes

```bash
./scripts/validate-packages.sh omen
```

### Revisar servicios fallidos

```bash
systemctl --failed
systemctl --user --failed
```

---

## 18. XDG user directories

El paquete:

```text
configs/xdg-user-dirs
```

gestiona:

```text
~/.config/user-dirs.conf
~/.config/user-dirs.dirs
```

No crea un directorio `~/.config/xdg`.

Los directorios físicos deben existir:

```bash
mkdir -p "$HOME/Desktop" "$HOME/Downloads"
```

Comprobar:

```bash
xdg-user-dir DESKTOP
xdg-user-dir DOWNLOAD
xdg-user-dir DOCUMENTS
```

No ejecutar `xdg-user-dirs-update` sin revisar primero si reescribirá los
archivos gestionados por Stow.

---

## 19. Compatibilidad futura de Hyprland

La configuración actual utiliza:

```text
hyprland.conf
```

Antes de una actualización mayor de Hyprland debe revisarse la documentación
de la versión instalada.

Comprobar versión:

```bash
hyprctl version
pacman -Qi hyprland
```

No convertir automáticamente toda la configuración a un formato nuevo durante
una actualización rutinaria. La conversión debe realizarse en una rama
separada, con backups y manteniendo una sesión o TTY de recuperación.

---

## 20. Checklist de mantenimiento

Antes de publicar cambios importantes:

```bash
git status --short
git diff --check

bash -n scripts/*.sh
bash -n install/*.sh

./scripts/stow-preflight.sh
./scripts/check-desktop-config.sh
./scripts/validate-packages.sh omen

hyprctl reload
hyprctl configerrors
```

Después:

```bash
git add -A

git diff --cached --check
git diff --cached --stat
git diff --cached

git commit -m "descripción clara"
git push -u origin HEAD
```

Nunca fusionar una reorganización importante en `main` sin:

- probar una sesión completa;
- cerrar sesión y volver a entrar;
- verificar Waybar;
- verificar Hyprlock;
- verificar Kitty;
- verificar Wofi;
- verificar Okular;
- comprobar enlaces;
- comprobar perfiles;
- comprobar que no hay credenciales;
- mantener un backup fuera del repositorio.
