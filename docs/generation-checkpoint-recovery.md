# Offline recovery from a generation checkpoint

This runbook restores the files directly contained in root plus home state
associated with one retained NixOS system generation. Nested root subvolumes
are handled separately as described below. It is specific to the current
`thinkbook` layout:

| Purpose | Filesystem UUID | Top-level subvolume |
| --- | --- | --- |
| root | `3ddc29ee-0df8-4376-a305-392fac6231e9` | `@` |
| home | `3ddc29ee-0df8-4376-a305-392fac6231e9` | `@home` |
| Nix store and profiles | `3ddc29ee-0df8-4376-a305-392fac6231e9` | `@nix` |
| managed checkpoints | `3ddc29ee-0df8-4376-a305-392fac6231e9` | `@nixos-snapshots` |
| data | `990f90b6-0487-4379-b294-eb9327838c87` | `@data` |
| GRUB/EFI system partition | `B0BA-0BA8` | not Btrfs |

The procedure deliberately does not delete a subvolume. The pre-recovery
`@` and `@home` subvolumes are renamed and retained, so the operation can be
reversed from rescue media. Here, "root state" means files directly owned by
`@`; it does not include nested Btrfs subvolumes because Btrfs snapshots are
not recursive.

## Boundaries and prerequisites

- Use a trusted NixOS rescue/install image with Bash, `btrfs-progs`, `jq`,
  `util-linux`, and GNU coreutils.
- Shut the installed system down. Do not perform this procedure while it is
  running, suspended, or hibernated.
- Do not separately mount the installed `@`, `@home`, or `@nix` subvolumes.
  This procedure mounts only Btrfs top-level subvolume ID 5.
- A checkpoint is a same-filesystem recovery point, not a backup. It does not
  survive loss or corruption of the system drive.
- The managed pair covers only `@` and `@home`. It excludes `@nix`, `/boot`,
  swap, and the separate `/data` filesystem. In particular, this procedure
  must never mount or modify UUID `990f90b6-0487-4379-b294-eb9327838c87`.
- Root and home were captured moments apart, not transactionally. A checkpoint
  may therefore contain application state from slightly different instants.
- The active root currently has five nested subvolumes: `/tmp`, `/var/tmp`,
  `/srv`, `/var/lib/machines`, and `/var/lib/portables`. A root checkpoint
  contains only ordinary empty directory stubs at those paths. This runbook
  treats `/tmp` and `/var/tmp` as disposable; their contents are not restored.
  It refuses recovery unless `/srv`, `/var/lib/machines`, and
  `/var/lib/portables` are empty. If any stores persistent data, stop and make
  a separately verified off-device backup and recovery plan for it.
- Restoring the pair does not select a NixOS closure, change the system profile,
  or regenerate GRUB. The matching generation closure must still exist in
  `@nix`, and its GRUB entry must still exist on the EFI system partition.

If any identity or validation check below fails, stop. Do not substitute a
similarly named path and do not weaken a check to continue.

## 1. Enter a root Bash shell and mount the top level

Boot the rescue image, open a terminal, and enter a root login shell first:

```bash
sudo -i
```

At the root prompt, start Bash if necessary. Then run the following block as a
single Bash session; later sections depend on the variables and traps it sets:

```bash
if [ -z "${BASH_VERSION:-}" ]; then
  printf 'Refusing: start Bash before continuing\n' >&2
  exit 1
fi
set -Eeuo pipefail
export LC_ALL=C

SYSTEM_FS_UUID='3ddc29ee-0df8-4376-a305-392fac6231e9'
ESP_UUID='B0BA-0BA8'
TOP='/mnt/nixos-recovery-top'
ESP='/mnt/nixos-recovery-esp'
WORK=$(mktemp -d /run/nixos-checkpoint-recovery.XXXXXX)
chmod 0700 "${WORK}"

cleanup_work() {
  rm -f -- \
    "${WORK}/directory-entry" \
    "${WORK}/active-root-nested-subvolumes" \
    "${WORK}/active-home-nested-subvolumes" \
    "${WORK}/expected-root-nested-subvolumes" \
    "${WORK}/staged-root-nested-subvolumes" \
    "${WORK}/selected-manifest.json" \
    "${WORK}/generation-link-target" \
    "${WORK}/expected-generation-link-target" \
    "${WORK}/original-generation-link-target" \
    "${WORK}/expected-original-generation-link-target" \
    "${WORK}/grub-entry" \
    "${WORK}/grub-boot-files" \
    "${WORK}/grub-generation-headers" \
    "${WORK}/original-grub-entry" \
    "${WORK}/original-grub-boot-files" \
    "${WORK}/original-grub-generation-headers"
  rmdir -- "${WORK}"
}
trap cleanup_work EXIT

assert_device_unmounted() {
  local device=$1 mount_table matches status

  # First require a successful full-table read so an unavailable or malformed
  # mount table cannot be mistaken for "no matching mount".
  if ! mount_table=$(findmnt -rn -o TARGET,SOURCE); then
    printf 'Refusing: cannot enumerate the mount table\n' >&2
    return 1
  fi

  if matches=$(findmnt -rn -S "${device}" -o TARGET,SOURCE); then
    status=0
  else
    status=$?
  fi
  case "${status}" in
    0)
      [[ -n ${matches} ]] || {
        printf 'Refusing: findmnt returned an empty successful source query\n' >&2
        return 1
      }
      ;;
    1)
      [[ -z ${matches} ]] || {
        printf 'Refusing: failed source query returned unexpected output\n' >&2
        return 1
      }
      return 0
      ;;
    *)
      printf 'Refusing: cannot query mounts for %s (findmnt status %s)\n' \
        "${device}" "${status}" >&2
      return 1
      ;;
  esac
  if [[ -n ${matches} ]]; then
    printf 'Refusing: %s is already mounted:\n%s\n' \
      "${device}" "${matches}" >&2
    return 1
  fi
}

assert_empty_directory() {
  local directory=$1

  if ! find "${directory}" -mindepth 1 -maxdepth 1 -print0 -quit \
    >"${WORK}/directory-entry"; then
    printf 'Refusing: cannot inspect directory %s\n' "${directory}" >&2
    return 1
  fi
  [[ ! -s ${WORK}/directory-entry ]]
}

assert_ordinary_empty_directory() {
  local directory=$1 inode

  [[ -d ${directory} && ! -L ${directory} ]]
  if btrfs subvolume show "${directory}" >/dev/null 2>&1; then
    printf 'Refusing: expected an ordinary directory stub, found a subvolume: %s\n' \
      "${directory}" >&2
    return 1
  fi
  if ! inode=$(stat -c '%i' -- "${directory}"); then
    printf 'Refusing: cannot inspect directory inode %s\n' "${directory}" >&2
    return 1
  fi
  [[ ${inode} =~ ^[0-9]+$ && ${inode} != 256 ]]
  assert_empty_directory "${directory}"
}

assert_subvolume_directory() {
  local directory=$1 inode

  [[ -d ${directory} && ! -L ${directory} ]]
  btrfs subvolume show "${directory}" >/dev/null
  if ! inode=$(stat -c '%i' -- "${directory}"); then
    printf 'Refusing: cannot inspect subvolume inode %s\n' "${directory}" >&2
    return 1
  fi
  [[ ${inode} == 256 ]]
}

subvolume_uuid() {
  local directory=$1 uuid

  if ! uuid=$(btrfs subvolume show "${directory}" \
    | awk '$1 == "UUID:" && !found {print $2; found = 1}'); then
    printf 'Refusing: cannot inspect subvolume UUID %s\n' "${directory}" >&2
    return 1
  fi
  [[ ${uuid} =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]
  printf '%s\n' "${uuid,,}"
}

assert_subvolume_uuid() {
  local directory=$1 expected=$2 actual

  assert_subvolume_directory "${directory}"
  actual=$(subvolume_uuid "${directory}")
  [[ ${actual} == "${expected,,}" ]]
}

assert_not_mountpoint() {
  local directory=$1 status

  if mountpoint -q -- "${directory}"; then
    status=0
  else
    status=$?
  fi
  case "${status}" in
    0)
      printf 'Refusing: %s is already a mount point\n' "${directory}" >&2
      return 1
      ;;
    32)
      return 0
      ;;
    *)
      printf 'Refusing: cannot inspect mount point %s (status %s)\n' \
        "${directory}" "${status}" >&2
      return 1
      ;;
  esac
}

if ! SYSTEM_DEVICE=$(readlink -e "/dev/disk/by-uuid/${SYSTEM_FS_UUID}"); then
  printf 'Refusing: cannot resolve the installed system filesystem\n' >&2
  exit 1
fi

[[ -b ${SYSTEM_DEVICE} ]]
if ! ACTUAL_SYSTEM_FS_UUID=$(blkid -s UUID -o value "${SYSTEM_DEVICE}"); then
  printf 'Refusing: cannot read the installed filesystem UUID\n' >&2
  exit 1
fi
[[ ${ACTUAL_SYSTEM_FS_UUID} == "${SYSTEM_FS_UUID}" ]]
assert_device_unmounted "${SYSTEM_DEVICE}"

install -d -m 0700 "${TOP}" "${ESP}"
[[ -d ${TOP} && ! -L ${TOP} ]]
[[ -d ${ESP} && ! -L ${ESP} ]]
assert_not_mountpoint "${TOP}"
assert_not_mountpoint "${ESP}"
assert_empty_directory "${TOP}"
assert_empty_directory "${ESP}"
mount -t btrfs -o subvolid=5,rw,nodev,nosuid,noexec "${SYSTEM_DEVICE}" "${TOP}"

if ! TOP_SUBVOLUME_ID=$(btrfs subvolume show "${TOP}" \
  | awk '$1 == "Subvolume" && $2 == "ID:" {print $3}'); then
  printf 'Refusing: cannot inspect the mounted top-level subvolume\n' >&2
  exit 1
fi
[[ ${TOP_SUBVOLUME_ID} == 5 ]]
if ! TOP_MOUNT_OPTIONS=$(findmnt -n -o OPTIONS --target "${TOP}"); then
  printf 'Refusing: cannot inspect top-level mount options\n' >&2
  exit 1
fi
[[ ",${TOP_MOUNT_OPTIONS}," == *,rw,* ]]
if ! TOP_MOUNT_SOURCE=$(findmnt -n -o SOURCE --target "${TOP}"); then
  printf 'Refusing: cannot inspect the top-level mount source\n' >&2
  exit 1
fi
# For top-level FSROOT `/`, findmnt may append the exact suffix `[/]` or omit it.
if [[ ${TOP_MOUNT_SOURCE} == *'['* || ${TOP_MOUNT_SOURCE} == *']'* ]]; then
  [[ ${TOP_MOUNT_SOURCE} == *'[/]' ]]
  TOP_MOUNT_SOURCE=${TOP_MOUNT_SOURCE%'[/]'}
  [[ ${TOP_MOUNT_SOURCE} != *'['* && ${TOP_MOUNT_SOURCE} != *']'* ]]
fi
if ! TOP_MOUNT_SOURCE=$(readlink -e -- "${TOP_MOUNT_SOURCE}"); then
  printf 'Refusing: cannot resolve the top-level mount source\n' >&2
  exit 1
fi
[[ ${TOP_MOUNT_SOURCE} == "${SYSTEM_DEVICE}" ]]
if ! TOP_MOUNT_FSROOT=$(findmnt -n -o FSROOT --target "${TOP}"); then
  printf 'Refusing: cannot inspect the top-level filesystem root\n' >&2
  exit 1
fi
[[ ${TOP_MOUNT_FSROOT} == / ]]
if ! TOP_MOUNT_FSTYPE=$(findmnt -n -o FSTYPE --target "${TOP}"); then
  printf 'Refusing: cannot inspect the top-level filesystem type\n' >&2
  exit 1
fi
[[ ${TOP_MOUNT_FSTYPE} == btrfs ]]
if ! ACTUAL_SYSTEM_FS_UUID=$(blkid -s UUID -o value "${SYSTEM_DEVICE}"); then
  printf 'Refusing: cannot re-read the installed filesystem UUID\n' >&2
  exit 1
fi
[[ ${ACTUAL_SYSTEM_FS_UUID} == "${SYSTEM_FS_UUID}" ]]
```

`assert_device_unmounted` requires a successful full mount-table enumeration,
then queries `findmnt` by the canonical device source. This avoids Btrfs's
anonymous mounted device numbers, which do not equal the physical partition's
major/minor identity. If it lists a target, inspect why the rescue environment
mounted it and unmount that exact target before starting over; do not use a
recursive or wildcard unmount.

### Validate nested-subvolume boundaries

Before selecting a checkpoint, enumerate the live root topology. The command
must succeed and report exactly five descendants. Verifying the five exact
paths as subvolumes plus the exact count makes any additional nested subvolume
a hard failure. Home is required to have no nested subvolume.

```bash
EXPECTED_ROOT_NESTED=(
  tmp
  var/tmp
  srv
  var/lib/machines
  var/lib/portables
)
printf '%s\n' "${EXPECTED_ROOT_NESTED[@]}" \
  >"${WORK}/expected-root-nested-subvolumes"

assert_subvolume_directory "${TOP}/@"
assert_subvolume_directory "${TOP}/@home"
if ! btrfs subvolume list -o "${TOP}/@" \
  >"${WORK}/active-root-nested-subvolumes"; then
  printf 'Refusing: cannot enumerate active root nested subvolumes\n' >&2
  exit 1
fi
mapfile -t ACTIVE_ROOT_NESTED_LINES \
  <"${WORK}/active-root-nested-subvolumes"
(( ${#ACTIVE_ROOT_NESTED_LINES[@]} == ${#EXPECTED_ROOT_NESTED[@]} ))
for NESTED_LINE in "${ACTIVE_ROOT_NESTED_LINES[@]}"; do
  [[ -n ${NESTED_LINE} ]]
done
for NESTED_RELATIVE in "${EXPECTED_ROOT_NESTED[@]}"; do
  assert_subvolume_directory "${TOP}/@/${NESTED_RELATIVE}"
done

if ! btrfs subvolume list -o "${TOP}/@home" \
  >"${WORK}/active-home-nested-subvolumes"; then
  printf 'Refusing: cannot enumerate active home nested subvolumes\n' >&2
  exit 1
fi
[[ ! -s ${WORK}/active-home-nested-subvolumes ]]

for PERSISTENT_NESTED in srv var/lib/machines var/lib/portables; do
  assert_empty_directory "${TOP}/@/${PERSISTENT_NESTED}"
done

printf '%s\n' 'Active root nested-subvolume enumeration:'
cat -- "${WORK}/active-root-nested-subvolumes"
printf '%s\n' 'Expected exact relative paths:'
cat -- "${WORK}/expected-root-nested-subvolumes"
read -r -p 'Type NESTED-TOPOLOGY-VERIFIED to confirm the exact topology: ' \
  NESTED_CONFIRMATION
[[ ${NESTED_CONFIRMATION} == NESTED-TOPOLOGY-VERIFIED ]]
```

The emptiness checks use a successfully completed `find` through
`assert_empty_directory`; they do not equate inspection failure with an empty
directory. Existing contents of `/tmp` and `/var/tmp` are intentionally not
copied and will be discarded by the restore. If any persistent nested path is
non-empty, or an unexpected root/home nested subvolume is present, stop. This
procedure does not back up or migrate that data.

## 2. Select one complete generation set

Inspect the available set names and their manifests:

```bash
STORAGE="${TOP}/@nixos-snapshots"
[[ -d ${STORAGE} && ! -L ${STORAGE} ]]
btrfs subvolume show "${STORAGE}" >/dev/null

shopt -s nullglob
SET_CANDIDATES=("${STORAGE}"/g*-*)
shopt -u nullglob
(( ${#SET_CANDIDATES[@]} > 0 ))

for SET_CANDIDATE in "${SET_CANDIDATES[@]}"; do
  [[ -d ${SET_CANDIDATE} && ! -L ${SET_CANDIDATE} ]] || {
    printf 'invalid candidate path: %s\n' "${SET_CANDIDATE}" >&2
    continue
  }
  CANDIDATE_MANIFEST="${SET_CANDIDATE}/manifest.json"
  [[ -f ${CANDIDATE_MANIFEST} && ! -L ${CANDIDATE_MANIFEST} ]] || {
    printf 'candidate has no regular manifest: %s\n' "${SET_CANDIDATE}" >&2
    continue
  }
  printf '%s\t' "${SET_CANDIDATE##*/}"
  jq -er '[.generation, .storeHash, .createdAt, .systemPath] | @tsv' \
    "${CANDIDATE_MANIFEST}"
done
```

Choose exactly one directory name from this output. Replace the value below;
do not use a glob or select merely by creation time:

```bash
SET_KEY='REPLACE_WITH_EXACT_gGENERATION_STOREHASH'

[[ ${SET_KEY} =~ ^g([1-9][0-9]*)-([0-9a-z]{32})$ ]]
GENERATION=${BASH_REMATCH[1]}
STORE_HASH=${BASH_REMATCH[2]}
SET_DIR="${STORAGE}/${SET_KEY}"
MANIFEST="${SET_DIR}/manifest.json"

[[ -d ${SET_DIR} && ! -L ${SET_DIR} ]]
[[ -f ${MANIFEST} && ! -L ${MANIFEST} ]]

shopt -s nullglob dotglob
SET_ENTRIES=("${SET_DIR}"/*)
shopt -u nullglob dotglob
(( ${#SET_ENTRIES[@]} == 3 ))
declare -A SET_ENTRY_SEEN=()
for SET_ENTRY in "${SET_ENTRIES[@]}"; do
  SET_ENTRY_NAME=${SET_ENTRY##*/}
  case "${SET_ENTRY_NAME}" in
    manifest.json | root | home)
      SET_ENTRY_SEEN["${SET_ENTRY_NAME}"]=1
      ;;
    *)
      printf 'Refusing: unexpected checkpoint entry: %s\n' "${SET_ENTRY}" >&2
      exit 1
      ;;
  esac
done
[[ -n ${SET_ENTRY_SEEN[manifest.json]+x} ]]
[[ -n ${SET_ENTRY_SEEN[root]+x} ]]
[[ -n ${SET_ENTRY_SEEN[home]+x} ]]
```

The final check requires exactly `manifest.json`, `root`, and `home`; the member
checks in the next section ensure an unexpected entry cannot replace either
expected member.

## 3. Validate the manifest, members, generation, and boot entry

Validate the same schema and identity invariants enforced by
`nixos-generation-snapshot`, plus this host's exact two-member mapping:

```bash
MANIFEST_SOURCE=${MANIFEST}
[[ -f ${MANIFEST_SOURCE} && ! -L ${MANIFEST_SOURCE} ]]
if ! cp --reflink=never -- "${MANIFEST_SOURCE}" "${WORK}/selected-manifest.json"; then
  printf 'Refusing: cannot make a stable copy of the selected manifest\n' >&2
  exit 1
fi
chmod 0400 "${WORK}/selected-manifest.json"
MANIFEST="${WORK}/selected-manifest.json"

jq -e --argjson generation "${GENERATION}" --arg hash "${STORE_HASH}" '
  (.schema == 1)
  and (.status == "complete")
  and (.phase == "checkpoint")
  and (.generation | type == "number")
  and (.generation > 0)
  and (.generation == (.generation | floor))
  and (.generation == $generation)
  and (.systemPath | type == "string"
    and test("^/nix/store/[0-9a-z]{32}-[^/]+\\z")
    and all(explode[]; . >= 32 and . != 127))
  and (.storeHash | type == "string" and test("^[0-9a-z]{32}\\z"))
  and (.storeHash == $hash)
  and (.systemPath | test("^/nix/store/" + $hash + "-[^/]+\\z"))
  and (.createdAt | type == "string" and all(explode[]; . >= 32 and . != 127))
  and (.members | type == "object" and length > 0)
  and all(.members | to_entries[];
    (.key | test("^[A-Za-z0-9][A-Za-z0-9_-]*\\z"))
    and (.value | type == "object")
    and (.value.sourceSubvolume | type == "string")
    and (.value.sourceSubvolume | length > 0)
    and (.value.sourceSubvolume | startswith("/") | not)
    and (.value.sourceSubvolume | all(explode[]; . >= 32 and . != 127))
    and all(.value.sourceSubvolume | split("/")[]; length > 0 and . != "." and . != "..")
    and (.value.uuid | type == "string"
      and test("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\\z")))
  and ((.members | keys | sort) == ["home", "root"])
  and (.members.root.sourceSubvolume == "@")
  and (.members.home.sourceSubvolume == "@home")
' "${MANIFEST}" >/dev/null

if ! SYSTEM_PATH=$(jq -er '.systemPath' "${MANIFEST}"); then
  printf 'Refusing: cannot read the validated system path\n' >&2
  exit 1
fi
[[ ${SYSTEM_PATH} == "/nix/store/${STORE_HASH}-"* ]]

for MEMBER in root home; do
  MEMBER_PATH="${SET_DIR}/${MEMBER}"
  [[ -d ${MEMBER_PATH} && ! -L ${MEMBER_PATH} ]]
  btrfs subvolume show "${MEMBER_PATH}" >/dev/null

  if ! EXPECTED_UUID=$(jq -er --arg member "${MEMBER}" \
    '.members[$member].uuid' "${MANIFEST}"); then
    printf 'Refusing: cannot read the validated UUID for %s\n' "${MEMBER}" >&2
    exit 1
  fi
  if ! ACTUAL_UUID=$(btrfs subvolume show "${MEMBER_PATH}" \
    | awk '$1 == "UUID:" && !found {print $2; found = 1}'); then
    printf 'Refusing: cannot inspect the UUID for %s\n' "${MEMBER}" >&2
    exit 1
  fi
  [[ -n ${ACTUAL_UUID} && ${ACTUAL_UUID,,} == "${EXPECTED_UUID,,}" ]]
  [[ $(btrfs property get -ts "${MEMBER_PATH}" ro) == 'ro=true' ]]
done

# A parent root snapshot does not include nested subvolume contents. It must
# expose exactly the five expected paths as ordinary empty directory stubs.
for NESTED_RELATIVE in "${EXPECTED_ROOT_NESTED[@]}"; do
  assert_ordinary_empty_directory "${SET_DIR}/root/${NESTED_RELATIVE}"
done
if ! btrfs subvolume list -o "${SET_DIR}/root" \
  >"${WORK}/staged-root-nested-subvolumes"; then
  printf 'Refusing: cannot inspect checkpoint root descendants\n' >&2
  exit 1
fi
[[ ! -s ${WORK}/staged-root-nested-subvolumes ]]

GENERATION_LINK="${TOP}/@nix/var/nix/profiles/system-${GENERATION}-link"
[[ -L ${GENERATION_LINK} ]]
SYSTEM_STORE_DIR="${TOP}/@nix/store/${SYSTEM_PATH#/nix/store/}"
btrfs subvolume show "${TOP}/@nix" >/dev/null
[[ -d ${SYSTEM_STORE_DIR} ]]
[[ -x ${SYSTEM_STORE_DIR}/bin/switch-to-configuration ]]
[[ -r ${SYSTEM_STORE_DIR}/kernel ]]
[[ -r ${SYSTEM_STORE_DIR}/initrd ]]

readlink -z -- "${GENERATION_LINK}" >"${WORK}/generation-link-target"
printf '%s\0' "${SYSTEM_PATH}" >"${WORK}/expected-generation-link-target"
cmp -s -- \
  "${WORK}/generation-link-target" \
  "${WORK}/expected-generation-link-target"

# Record the pre-recovery system/profile identity for a complete reverse path.
CURRENT_PROFILE_LINK="${TOP}/@nix/var/nix/profiles/system"
[[ -L ${CURRENT_PROFILE_LINK} ]]
if ! CURRENT_PROFILE_TARGET=$(readlink -- "${CURRENT_PROFILE_LINK}"); then
  printf 'Refusing: cannot read the pre-recovery current system profile\n' >&2
  exit 1
fi
CURRENT_PROFILE_NAME=${CURRENT_PROFILE_TARGET##*/}
[[ ${CURRENT_PROFILE_NAME} =~ ^system-([1-9][0-9]*)-link$ ]]
ORIGINAL_GENERATION=${BASH_REMATCH[1]}
ORIGINAL_GENERATION_LINK="${TOP}/@nix/var/nix/profiles/system-${ORIGINAL_GENERATION}-link"
[[ -L ${ORIGINAL_GENERATION_LINK} ]]
if ! ORIGINAL_SYSTEM_PATH=$(readlink -- "${ORIGINAL_GENERATION_LINK}"); then
  printf 'Refusing: cannot read the pre-recovery generation target\n' >&2
  exit 1
fi
[[ ${ORIGINAL_SYSTEM_PATH} =~ ^/nix/store/[0-9a-z]{32}-[^/]+$ ]]
ORIGINAL_SYSTEM_STORE_DIR="${TOP}/@nix/store/${ORIGINAL_SYSTEM_PATH#/nix/store/}"
[[ -d ${ORIGINAL_SYSTEM_STORE_DIR} ]]
[[ -x ${ORIGINAL_SYSTEM_STORE_DIR}/bin/switch-to-configuration ]]
[[ -r ${ORIGINAL_SYSTEM_STORE_DIR}/kernel ]]
[[ -r ${ORIGINAL_SYSTEM_STORE_DIR}/initrd ]]
readlink -z -- "${ORIGINAL_GENERATION_LINK}" \
  >"${WORK}/original-generation-link-target"
printf '%s\0' "${ORIGINAL_SYSTEM_PATH}" \
  >"${WORK}/expected-original-generation-link-target"
cmp -s -- \
  "${WORK}/original-generation-link-target" \
  "${WORK}/expected-original-generation-link-target"

if ! ESP_DEVICE=$(readlink -e "/dev/disk/by-uuid/${ESP_UUID}"); then
  printf 'Refusing: cannot resolve the EFI system partition\n' >&2
  exit 1
fi
[[ -b ${ESP_DEVICE} ]]
if ! ACTUAL_ESP_UUID=$(blkid -s UUID -o value "${ESP_DEVICE}"); then
  printf 'Refusing: cannot read the EFI system partition UUID\n' >&2
  exit 1
fi
[[ ${ACTUAL_ESP_UUID} == "${ESP_UUID}" ]]
assert_device_unmounted "${ESP_DEVICE}"
mount -t vfat -o ro,nodev,nosuid,noexec "${ESP_DEVICE}" "${ESP}"

if ! awk -v generation="${GENERATION}" '
  BEGIN { prefix = "menuentry \"NixOS - Configuration " generation " (" }
  index($0, prefix) == 1 { print }
' "${ESP}/grub/grub.cfg" >"${WORK}/grub-generation-headers"; then
  printf 'Refusing: cannot count GRUB generation headers\n' >&2
  exit 1
fi
mapfile -t GRUB_GENERATION_HEADERS <"${WORK}/grub-generation-headers"
(( ${#GRUB_GENERATION_HEADERS[@]} == 1 ))

if ! awk -v generation="${GENERATION}" '
  BEGIN { prefix = "menuentry \"NixOS - Configuration " generation " (" }
  index($0, prefix) == 1 {
    if (found) exit 2
    found = 1
    inside = 1
  }
  inside { print }
  inside && $0 == "}" {
    closed = 1
    inside = 0
    exit
  }
  END { if (!found || !closed) exit 1 }
' "${ESP}/grub/grub.cfg" >"${WORK}/grub-entry"; then
  printf 'Refusing: cannot isolate the GRUB entry for generation %s\n' \
    "${GENERATION}" >&2
  exit 1
fi
grep -Fq -- "init=${SYSTEM_PATH}/init " "${WORK}/grub-entry"
if ! sed -nE \
  's#^[[:space:]]*(linux|initrd)[[:space:]]+\([^)]*\)/+([^[:space:]]+).*#\1 \2#p' \
  "${WORK}/grub-entry" >"${WORK}/grub-boot-files"; then
  printf 'Refusing: cannot parse the GRUB boot artifacts\n' >&2
  exit 1
fi
mapfile -t GRUB_BOOT_FILES <"${WORK}/grub-boot-files"
(( ${#GRUB_BOOT_FILES[@]} == 2 ))
declare -A GRUB_BOOT_KIND_SEEN=()
declare -A GRUB_BOOT_PATHS=()
for GRUB_BOOT_RECORD in "${GRUB_BOOT_FILES[@]}"; do
  read -r GRUB_BOOT_KIND GRUB_BOOT_PATH GRUB_BOOT_EXTRA <<<"${GRUB_BOOT_RECORD}"
  [[ -z ${GRUB_BOOT_EXTRA} ]]
  [[ ${GRUB_BOOT_KIND} == linux || ${GRUB_BOOT_KIND} == initrd ]]
  [[ -z ${GRUB_BOOT_KIND_SEEN[${GRUB_BOOT_KIND}]+x} ]]
  [[ ${GRUB_BOOT_PATH} =~ ^kernels/[0-9A-Za-z._+-]+$ ]]
  [[ -f ${ESP}/${GRUB_BOOT_PATH} ]]
  GRUB_BOOT_KIND_SEEN["${GRUB_BOOT_KIND}"]=1
  GRUB_BOOT_PATHS["${GRUB_BOOT_KIND}"]=${GRUB_BOOT_PATH}
done
[[ -n ${GRUB_BOOT_KIND_SEEN[linux]+x} ]]
[[ -n ${GRUB_BOOT_KIND_SEEN[initrd]+x} ]]
cmp -s -- "${SYSTEM_STORE_DIR}/kernel" \
  "${ESP}/${GRUB_BOOT_PATHS[linux]}"
cmp -s -- "${SYSTEM_STORE_DIR}/initrd" \
  "${ESP}/${GRUB_BOOT_PATHS[initrd]}"

if ! awk -v generation="${ORIGINAL_GENERATION}" '
  BEGIN { prefix = "menuentry \"NixOS - Configuration " generation " (" }
  index($0, prefix) == 1 { print }
' "${ESP}/grub/grub.cfg" >"${WORK}/original-grub-generation-headers"; then
  printf 'Refusing: cannot count original GRUB generation headers\n' >&2
  exit 1
fi
mapfile -t ORIGINAL_GRUB_GENERATION_HEADERS \
  <"${WORK}/original-grub-generation-headers"
(( ${#ORIGINAL_GRUB_GENERATION_HEADERS[@]} == 1 ))
if ! awk -v generation="${ORIGINAL_GENERATION}" '
  BEGIN { prefix = "menuentry \"NixOS - Configuration " generation " (" }
  index($0, prefix) == 1 { found = 1; inside = 1 }
  inside { print }
  inside && $0 == "}" { closed = 1; exit }
  END { if (!found || !closed) exit 1 }
' "${ESP}/grub/grub.cfg" >"${WORK}/original-grub-entry"; then
  printf 'Refusing: cannot isolate original GRUB generation %s\n' \
    "${ORIGINAL_GENERATION}" >&2
  exit 1
fi
grep -Fq -- "init=${ORIGINAL_SYSTEM_PATH}/init " \
  "${WORK}/original-grub-entry"
if ! sed -nE \
  's#^[[:space:]]*(linux|initrd)[[:space:]]+\([^)]*\)/+([^[:space:]]+).*#\1 \2#p' \
  "${WORK}/original-grub-entry" >"${WORK}/original-grub-boot-files"; then
  printf 'Refusing: cannot parse original GRUB boot artifacts\n' >&2
  exit 1
fi
mapfile -t ORIGINAL_GRUB_BOOT_FILES <"${WORK}/original-grub-boot-files"
(( ${#ORIGINAL_GRUB_BOOT_FILES[@]} == 2 ))
declare -A ORIGINAL_GRUB_BOOT_KIND_SEEN=()
declare -A ORIGINAL_GRUB_BOOT_PATHS=()
for ORIGINAL_GRUB_BOOT_RECORD in "${ORIGINAL_GRUB_BOOT_FILES[@]}"; do
  read -r ORIGINAL_GRUB_BOOT_KIND ORIGINAL_GRUB_BOOT_PATH ORIGINAL_GRUB_BOOT_EXTRA \
    <<<"${ORIGINAL_GRUB_BOOT_RECORD}"
  [[ -z ${ORIGINAL_GRUB_BOOT_EXTRA} ]]
  [[ ${ORIGINAL_GRUB_BOOT_KIND} == linux || ${ORIGINAL_GRUB_BOOT_KIND} == initrd ]]
  [[ -z ${ORIGINAL_GRUB_BOOT_KIND_SEEN[${ORIGINAL_GRUB_BOOT_KIND}]+x} ]]
  [[ ${ORIGINAL_GRUB_BOOT_PATH} =~ ^kernels/[0-9A-Za-z._+-]+$ ]]
  [[ -f ${ESP}/${ORIGINAL_GRUB_BOOT_PATH} ]]
  ORIGINAL_GRUB_BOOT_KIND_SEEN["${ORIGINAL_GRUB_BOOT_KIND}"]=1
  ORIGINAL_GRUB_BOOT_PATHS["${ORIGINAL_GRUB_BOOT_KIND}"]=${ORIGINAL_GRUB_BOOT_PATH}
done
[[ -n ${ORIGINAL_GRUB_BOOT_KIND_SEEN[linux]+x} ]]
[[ -n ${ORIGINAL_GRUB_BOOT_KIND_SEEN[initrd]+x} ]]
cmp -s -- "${ORIGINAL_SYSTEM_STORE_DIR}/kernel" \
  "${ESP}/${ORIGINAL_GRUB_BOOT_PATHS[linux]}"
cmp -s -- "${ORIGINAL_SYSTEM_STORE_DIR}/initrd" \
  "${ESP}/${ORIGINAL_GRUB_BOOT_PATHS[initrd]}"

printf 'Record these for a possible reverse restore:\nORIGINAL_GENERATION=%s\nORIGINAL_SYSTEM_PATH=%s\n' \
  "${ORIGINAL_GENERATION}" "${ORIGINAL_SYSTEM_PATH}"
```

If the generation link, store path, or GRUB check fails, do not restore the
mutable pair yet. This runbook does not reconstruct the Nix store or boot
artifacts. Repair those from a known-good NixOS environment, or choose another
fully retained generation set.

## 4. Stage writable root and home snapshots

The managed members must remain read-only. Create new writable snapshots under
unique temporary names and validate them before renaming anything active:

```bash
RESTORE_TAG="$(date -u +%Y%m%dT%H%M%SZ)-g${GENERATION}"
[[ ${RESTORE_TAG} =~ ^[0-9]{8}T[0-9]{6}Z-g[1-9][0-9]*$ ]]

ROOT_SOURCE="${SET_DIR}/root"
HOME_SOURCE="${SET_DIR}/home"
ROOT_STAGE="${TOP}/@.restore-${RESTORE_TAG}"
HOME_STAGE="${TOP}/@home.restore-${RESTORE_TAG}"
ROOT_OLD="${TOP}/@.pre-restore-${RESTORE_TAG}"
HOME_OLD="${TOP}/@home.pre-restore-${RESTORE_TAG}"

for PATH_TO_CREATE in "${ROOT_STAGE}" "${HOME_STAGE}" "${ROOT_OLD}" "${HOME_OLD}"; do
  [[ ! -e ${PATH_TO_CREATE} && ! -L ${PATH_TO_CREATE} ]]
done
for ACTIVE in "${TOP}/@" "${TOP}/@home"; do
  [[ -d ${ACTIVE} && ! -L ${ACTIVE} ]]
  btrfs subvolume show "${ACTIVE}" >/dev/null
  [[ $(btrfs property get -ts "${ACTIVE}" ro) == 'ro=false' ]]
done
ORIGINAL_ROOT_UUID=$(subvolume_uuid "${TOP}/@")
ORIGINAL_HOME_UUID=$(subvolume_uuid "${TOP}/@home")

btrfs subvolume snapshot "${ROOT_SOURCE}" "${ROOT_STAGE}"
btrfs subvolume snapshot "${HOME_SOURCE}" "${HOME_STAGE}"

for STAGED in "${ROOT_STAGE}" "${HOME_STAGE}"; do
  btrfs subvolume show "${STAGED}" >/dev/null
  [[ $(btrfs property get -ts "${STAGED}" ro) == 'ro=false' ]]
done
if ! STAGED_ROOT_PARENT_UUID=$(btrfs subvolume show "${ROOT_STAGE}" \
  | awk '$1 == "Parent" && $2 == "UUID:" {print $3}'); then
  printf 'Refusing: cannot inspect the staged root parent UUID\n' >&2
  exit 1
fi
if ! STAGED_HOME_PARENT_UUID=$(btrfs subvolume show "${HOME_STAGE}" \
  | awk '$1 == "Parent" && $2 == "UUID:" {print $3}'); then
  printf 'Refusing: cannot inspect the staged home parent UUID\n' >&2
  exit 1
fi
EXPECTED_ROOT_UUID=$(jq -er '.members.root.uuid' "${MANIFEST}")
EXPECTED_HOME_UUID=$(jq -er '.members.home.uuid' "${MANIFEST}")
[[ ${STAGED_ROOT_PARENT_UUID,,} == "${EXPECTED_ROOT_UUID,,}" ]]
[[ ${STAGED_HOME_PARENT_UUID,,} == "${EXPECTED_HOME_UUID,,}" ]]

# Replace the non-recursive root snapshot's five ordinary stubs with new,
# empty nested subvolumes. Never reuse or move the active pair's descendants;
# they remain inside ROOT_OLD for a complete rollback.
for NESTED_RELATIVE in "${EXPECTED_ROOT_NESTED[@]}"; do
  STAGED_STUB="${ROOT_STAGE}/${NESTED_RELATIVE}"
  assert_ordinary_empty_directory "${STAGED_STUB}"
  rmdir -- "${STAGED_STUB}"
  [[ ! -e ${STAGED_STUB} && ! -L ${STAGED_STUB} ]]
  btrfs subvolume create "${STAGED_STUB}"
done
chown 0:0 -- \
  "${ROOT_STAGE}/tmp" \
  "${ROOT_STAGE}/var/tmp" \
  "${ROOT_STAGE}/srv" \
  "${ROOT_STAGE}/var/lib/machines" \
  "${ROOT_STAGE}/var/lib/portables"
chmod 1777 -- "${ROOT_STAGE}/tmp" "${ROOT_STAGE}/var/tmp"
chmod 0755 -- "${ROOT_STAGE}/srv"
chmod 0700 -- \
  "${ROOT_STAGE}/var/lib/machines" \
  "${ROOT_STAGE}/var/lib/portables"
for NESTED_RELATIVE in "${EXPECTED_ROOT_NESTED[@]}"; do
  assert_subvolume_directory "${ROOT_STAGE}/${NESTED_RELATIVE}"
  assert_empty_directory "${ROOT_STAGE}/${NESTED_RELATIVE}"
done
[[ $(stat -c '%u:%g:%a' -- "${ROOT_STAGE}/tmp") == 0:0:1777 ]]
[[ $(stat -c '%u:%g:%a' -- "${ROOT_STAGE}/var/tmp") == 0:0:1777 ]]
[[ $(stat -c '%u:%g:%a' -- "${ROOT_STAGE}/srv") == 0:0:755 ]]
[[ $(stat -c '%u:%g:%a' -- "${ROOT_STAGE}/var/lib/machines") == 0:0:700 ]]
[[ $(stat -c '%u:%g:%a' -- "${ROOT_STAGE}/var/lib/portables") == 0:0:700 ]]
if ! btrfs subvolume list -o "${ROOT_STAGE}" \
  >"${WORK}/staged-root-nested-subvolumes"; then
  printf 'Refusing: cannot enumerate staged root nested subvolumes\n' >&2
  exit 1
fi
mapfile -t STAGED_ROOT_NESTED_LINES \
  <"${WORK}/staged-root-nested-subvolumes"
(( ${#STAGED_ROOT_NESTED_LINES[@]} == ${#EXPECTED_ROOT_NESTED[@]} ))
STAGED_ROOT_UUID=$(subvolume_uuid "${ROOT_STAGE}")
STAGED_HOME_UUID=$(subvolume_uuid "${HOME_STAGE}")
[[ ${STAGED_ROOT_UUID} != "${ORIGINAL_ROOT_UUID}" ]]
[[ ${STAGED_HOME_UUID} != "${ORIGINAL_HOME_UUID}" ]]
btrfs filesystem sync "${TOP}"

printf '%s\n' 'Record these exact values before the rename phase:'
printf 'RESTORE_TAG=%s\n' "${RESTORE_TAG}"
printf 'ORIGINAL_ROOT_UUID=%s\n' "${ORIGINAL_ROOT_UUID}"
printf 'ORIGINAL_HOME_UUID=%s\n' "${ORIGINAL_HOME_UUID}"
printf 'STAGED_ROOT_UUID=%s\n' "${STAGED_ROOT_UUID}"
printf 'STAGED_HOME_UUID=%s\n' "${STAGED_HOME_UUID}"
```

At this point the active subvolumes are unchanged. If any command failed, stop;
do not proceed to the rename phase. The staged root now has five new empty
nested subvolumes with the current topology and permissions. Contents of the
old nested subvolumes remain only in the retained pre-restore root.

## 5. Confirm and install the pair

Review every exact path, then type the requested set name. The error trap
attempts to reverse completed renames if a later rename fails. It never deletes
a subvolume.

```bash
printf 'checkpoint: %s\nroot source: %s\nhome source: %s\n' \
  "${SET_KEY}" "${ROOT_SOURCE}" "${HOME_SOURCE}"
printf 'old root retained as: %s\nold home retained as: %s\n' \
  "${ROOT_OLD}" "${HOME_OLD}"
read -r -p "Type RESTORE ${SET_KEY} to continue: " CONFIRMATION
[[ ${CONFIRMATION} == "RESTORE ${SET_KEY}" ]]

ROOT_MOVED=0
ROOT_INSTALLED=0
HOME_MOVED=0
HOME_INSTALLED=0

rollback_incomplete_rename() {
  local status=$1 rollback_failed=0
  trap - ERR INT TERM HUP
  set +e

  if (( HOME_INSTALLED )); then
    mv --no-copy --update=none-fail -T -- \
      "${TOP}/@home" "${HOME_STAGE}" || rollback_failed=1
  fi
  if (( HOME_MOVED )); then
    mv --no-copy --update=none-fail -T -- \
      "${HOME_OLD}" "${TOP}/@home" || rollback_failed=1
  fi
  if (( ROOT_INSTALLED )); then
    mv --no-copy --update=none-fail -T -- \
      "${TOP}/@" "${ROOT_STAGE}" || rollback_failed=1
  fi
  if (( ROOT_MOVED )); then
    mv --no-copy --update=none-fail -T -- \
      "${ROOT_OLD}" "${TOP}/@" || rollback_failed=1
  fi
  btrfs filesystem sync "${TOP}" || rollback_failed=1

  if (( rollback_failed )); then
    printf 'Automatic rename rollback was incomplete. Do not reboot; inspect only the exact paths printed above.\n' >&2
  else
    printf 'Rename phase was reversed; the original active pair is back in place.\n' >&2
  fi
  exit "${status}"
}

rename_for_restore() {
  local source=$1 destination=$2 flag_name=$3 status

  # Do not run a signal handler between a successful rename and recording it.
  trap '' INT TERM HUP
  if mv --no-copy --update=none-fail -T -- "${source}" "${destination}"; then
    printf -v "${flag_name}" '%s' 1
    trap 'rollback_incomplete_rename 130' INT TERM HUP
    return 0
  else
    status=$?
    trap 'rollback_incomplete_rename 130' INT TERM HUP
    return "${status}"
  fi
}

trap 'rollback_incomplete_rename $?' ERR
trap 'rollback_incomplete_rename 130' INT TERM HUP

rename_for_restore "${TOP}/@" "${ROOT_OLD}" ROOT_MOVED
rename_for_restore "${ROOT_STAGE}" "${TOP}/@" ROOT_INSTALLED
rename_for_restore "${TOP}/@home" "${HOME_OLD}" HOME_MOVED
rename_for_restore "${HOME_STAGE}" "${TOP}/@home" HOME_INSTALLED

btrfs filesystem sync "${TOP}"

for ACTIVE in "${TOP}/@" "${TOP}/@home"; do
  btrfs subvolume show "${ACTIVE}" >/dev/null
  [[ $(btrfs property get -ts "${ACTIVE}" ro) == 'ro=false' ]]
done
if ! ACTIVE_ROOT_PARENT_UUID=$(btrfs subvolume show "${TOP}/@" \
  | awk '$1 == "Parent" && $2 == "UUID:" {print $3}'); then
  printf 'Refusing: cannot inspect installed root parent UUID\n' >&2
  exit 1
fi
if ! ACTIVE_HOME_PARENT_UUID=$(btrfs subvolume show "${TOP}/@home" \
  | awk '$1 == "Parent" && $2 == "UUID:" {print $3}'); then
  printf 'Refusing: cannot inspect installed home parent UUID\n' >&2
  exit 1
fi
[[ ${ACTIVE_ROOT_PARENT_UUID,,} == "${EXPECTED_ROOT_UUID,,}" ]]
[[ ${ACTIVE_HOME_PARENT_UUID,,} == "${EXPECTED_HOME_UUID,,}" ]]
for RETAINED in "${ROOT_OLD}" "${HOME_OLD}"; do
  btrfs subvolume show "${RETAINED}" >/dev/null
done
trap - ERR INT TERM HUP
```

### Recover a rename phase interrupted by power loss

If the machine lost power anywhere in section 5, do not boot the installed
system and do not move a single member by inspection. Boot rescue media and
repeat only section 1 through the top-level mount and mount-identity checks,
including its root Bash session and helper definitions. Do **not** run the
"Validate nested-subvolume boundaries" subsection: an interrupted rename may
legitimately have no active `@` or `@home` name yet. Set the exact five values
recorded at the end of section 4, then run this state machine. Its only automatic
recovery target is the complete original root/home pair. It identifies every
candidate by UUID, not just by name, before performing a rename.

```bash
RESTORE_TAG='REPLACE_WITH_THE_EXACT_ORIGINAL_RESTORE_TAG'
ORIGINAL_ROOT_UUID='REPLACE_WITH_RECORDED_ORIGINAL_ROOT_UUID'
ORIGINAL_HOME_UUID='REPLACE_WITH_RECORDED_ORIGINAL_HOME_UUID'
STAGED_ROOT_UUID='REPLACE_WITH_RECORDED_STAGED_ROOT_UUID'
STAGED_HOME_UUID='REPLACE_WITH_RECORDED_STAGED_HOME_UUID'
[[ ${RESTORE_TAG} =~ ^[0-9]{8}T[0-9]{6}Z-g[1-9][0-9]*$ ]]
for RECORDED_UUID in \
  "${ORIGINAL_ROOT_UUID}" "${ORIGINAL_HOME_UUID}" \
  "${STAGED_ROOT_UUID}" "${STAGED_HOME_UUID}"; do
  [[ ${RECORDED_UUID} =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]
done
ORIGINAL_ROOT_UUID=${ORIGINAL_ROOT_UUID,,}
ORIGINAL_HOME_UUID=${ORIGINAL_HOME_UUID,,}
STAGED_ROOT_UUID=${STAGED_ROOT_UUID,,}
STAGED_HOME_UUID=${STAGED_HOME_UUID,,}
[[ ${ORIGINAL_ROOT_UUID} != "${STAGED_ROOT_UUID}" ]]
[[ ${ORIGINAL_HOME_UUID} != "${STAGED_HOME_UUID}" ]]

ACTIVE_ROOT="${TOP}/@"
ACTIVE_HOME="${TOP}/@home"
ROOT_STAGE="${TOP}/@.restore-${RESTORE_TAG}"
HOME_STAGE="${TOP}/@home.restore-${RESTORE_TAG}"
ROOT_OLD="${TOP}/@.pre-restore-${RESTORE_TAG}"
HOME_OLD="${TOP}/@home.pre-restore-${RESTORE_TAG}"

classify_restore_member() {
  local active=$1 staged=$2 original=$3
  local original_uuid=$4 staged_uuid=$5 result_name=$6
  local path uuid original_count=0 staged_count=0
  local original_path='' staged_path=''

  for path in "${active}" "${staged}" "${original}"; do
    [[ -e ${path} || -L ${path} ]] || continue
    assert_subvolume_directory "${path}"
    uuid=$(subvolume_uuid "${path}")
    if [[ ${uuid} == "${original_uuid}" ]]; then
      original_count=$((original_count + 1))
      original_path=${path}
    elif [[ ${uuid} == "${staged_uuid}" ]]; then
      staged_count=$((staged_count + 1))
      staged_path=${path}
    else
      printf 'Refusing: unexpected UUID %s at %s\n' "${uuid}" "${path}" >&2
      return 1
    fi
  done
  (( original_count == 1 && staged_count == 1 ))
  [[ -n ${original_path} && -n ${staged_path} ]]
  printf -v "${result_name}" '%s\t%s' "${original_path}" "${staged_path}"
}

classify_restore_member \
  "${ACTIVE_ROOT}" "${ROOT_STAGE}" "${ROOT_OLD}" \
  "${ORIGINAL_ROOT_UUID}" "${STAGED_ROOT_UUID}" ROOT_STATE
classify_restore_member \
  "${ACTIVE_HOME}" "${HOME_STAGE}" "${HOME_OLD}" \
  "${ORIGINAL_HOME_UUID}" "${STAGED_HOME_UUID}" HOME_STATE
IFS=$'\t' read -r ROOT_ORIGINAL_PATH ROOT_STAGED_PATH <<<"${ROOT_STATE}"
IFS=$'\t' read -r HOME_ORIGINAL_PATH HOME_STAGED_PATH <<<"${HOME_STATE}"
printf 'root original=%s staged=%s\nhome original=%s staged=%s\n' \
  "${ROOT_ORIGINAL_PATH}" "${ROOT_STAGED_PATH}" \
  "${HOME_ORIGINAL_PATH}" "${HOME_STAGED_PATH}"

read -r -p "Type REVERSE-PAIR ${RESTORE_TAG} to restore both originals: " \
  PAIR_CONFIRMATION
[[ ${PAIR_CONFIRMATION} == "REVERSE-PAIR ${RESTORE_TAG}" ]]

reverse_member_to_original() {
  local active=$1 staged_name=$2 original_path=$3 staged_path=$4
  local original_uuid=$5 staged_uuid=$6

  if [[ ${original_path} == "${active}" ]]; then
    assert_subvolume_uuid "${active}" "${original_uuid}"
    return 0
  fi

  if [[ ${staged_path} == "${active}" ]]; then
    if [[ -e ${staged_name} || -L ${staged_name} ]]; then
      printf 'Refusing: staged name is occupied before repair: %s\n' \
        "${staged_name}" >&2
      return 1
    fi
    mv --no-copy --update=none-fail -T -- "${staged_path}" "${staged_name}"
  elif [[ -e ${active} || -L ${active} ]]; then
    printf 'Refusing: active name contains neither recorded member: %s\n' \
      "${active}" >&2
    return 1
  fi

  mv --no-copy --update=none-fail -T -- "${original_path}" "${active}"
  assert_subvolume_uuid "${active}" "${original_uuid}"
  assert_subvolume_uuid "${staged_name}" "${staged_uuid}"
}

# Signals are ignored during this short deterministic repair. A second power
# loss is handled by booting rescue media again and re-auditing exact names;
# do not improvise member moves.
trap '' INT TERM HUP
reverse_member_to_original \
  "${ACTIVE_ROOT}" "${ROOT_STAGE}" "${ROOT_ORIGINAL_PATH}" \
  "${ROOT_STAGED_PATH}" "${ORIGINAL_ROOT_UUID}" "${STAGED_ROOT_UUID}"
reverse_member_to_original \
  "${ACTIVE_HOME}" "${HOME_STAGE}" "${HOME_ORIGINAL_PATH}" \
  "${HOME_STAGED_PATH}" "${ORIGINAL_HOME_UUID}" "${STAGED_HOME_UUID}"
btrfs filesystem sync "${TOP}"
assert_subvolume_uuid "${ACTIVE_ROOT}" "${ORIGINAL_ROOT_UUID}"
assert_subvolume_uuid "${ACTIVE_HOME}" "${ORIGINAL_HOME_UUID}"
trap - INT TERM HUP
```

This state machine leaves the unused staged pair in its exact `.restore-*`
names and never deletes it. Do not continue with the requested restore after this
repair. Terminate this rescue path now:

```bash
umount "${TOP}"
reboot
```

Explicitly select the recorded `ORIGINAL_GENERATION` in GRUB and follow the
final original-generation verification under "Reversing a completed data
restore." Do **not** execute the normal-success path below. Begin the runbook
again from section 1 only after the original pair and closure have passed that
verification if a restore is still wanted.

### Normal restore success path

The following normal-success path applies only when section 5 completed
without interruption. Unmount the exact rescue mounts and reboot:

```bash
umount "${ESP}"
umount "${TOP}"
reboot
```

In GRUB, explicitly select **NixOS - Configuration `GENERATION`**, using the
generation number recorded above. Letting GRUB boot a different default closure
does not complete a paired recovery.

## 6. Verify the recovered system

After booting, open a terminal and enter a new root login shell:

```bash
sudo -i
```

At the root prompt, start a fresh fail-closed Bash session before running any
verification or changing the profile:

```bash
if [ -z "${BASH_VERSION:-}" ]; then
  printf 'Refusing: start Bash before continuing\n' >&2
  exit 1
fi
set -Eeuo pipefail
export LC_ALL=C

GENERATION='REPLACE_WITH_THE_SELECTED_GENERATION_NUMBER'
EXPECTED_SYSTEM_PATH='REPLACE_WITH_THE_MANIFEST_SYSTEM_PATH'
[[ ${GENERATION} =~ ^[1-9][0-9]*$ ]]
[[ ${EXPECTED_SYSTEM_PATH} =~ ^/nix/store/[0-9a-z]{32}-[^/]+$ ]]
if ! SELECTED_SYSTEM=$(readlink -e "/nix/var/nix/profiles/system-${GENERATION}-link"); then
  printf 'Refusing: the selected system generation is no longer retained\n' >&2
  exit 1
fi
if ! RUNNING_SYSTEM=$(readlink -e /run/current-system); then
  printf 'Refusing: cannot identify the running system\n' >&2
  exit 1
fi
[[ ${SELECTED_SYSTEM} == "${EXPECTED_SYSTEM_PATH}" ]]
[[ ${RUNNING_SYSTEM} == "${SELECTED_SYSTEM}" ]]
```

Booting a GRUB generation does not normally move the `system` profile symlink.
After checking the restored applications and data, make the selected generation
the current profile only if that is the intended persistent rollback:

```bash
nix-env --switch-generation "${GENERATION}" -p /nix/var/nix/profiles/system
if ! CURRENT_PROFILE_SYSTEM=$(readlink -e /nix/var/nix/profiles/system); then
  printf 'Refusing: cannot identify the current system profile\n' >&2
  exit 1
fi
[[ ${CURRENT_PROFILE_SYSTEM} == "${RUNNING_SYSTEM}" ]]
"${RUNNING_SYSTEM}/bin/switch-to-configuration" switch
"${RUNNING_SYSTEM}/sw/bin/nixos-generation-snapshot" verify-current
```

Keep using `sudo nixos-clean-switch` for later configuration changes. Do not
run ordinary generation deletion or garbage collection until the recovered
system, profile mapping, and retained checkpoint have passed verification.

## Reversing a completed data restore

If the restored state is unsuitable, boot rescue media again and repeat the
entire root Bash setup, filesystem identity, and top-level mount checks from
section 1. Set `RESTORE_TAG` to the exact tag printed during the restore, plus
the original generation identity recorded in section 3. The original closure
and its exact GRUB entry must still be present; if either is missing, stop and
repair that boot boundary before changing mutable state.

```bash
RESTORE_TAG='REPLACE_WITH_THE_EXACT_ORIGINAL_RESTORE_TAG'
ORIGINAL_GENERATION='REPLACE_WITH_RECORDED_ORIGINAL_GENERATION'
ORIGINAL_SYSTEM_PATH='REPLACE_WITH_RECORDED_ORIGINAL_SYSTEM_PATH'
[[ ${RESTORE_TAG} =~ ^[0-9]{8}T[0-9]{6}Z-g[1-9][0-9]*$ ]]
[[ ${ORIGINAL_GENERATION} =~ ^[1-9][0-9]*$ ]]
[[ ${ORIGINAL_SYSTEM_PATH} =~ ^/nix/store/[0-9a-z]{32}-[^/]+$ ]]

ORIGINAL_GENERATION_LINK="${TOP}/@nix/var/nix/profiles/system-${ORIGINAL_GENERATION}-link"
ORIGINAL_SYSTEM_STORE_DIR="${TOP}/@nix/store/${ORIGINAL_SYSTEM_PATH#/nix/store/}"
[[ -L ${ORIGINAL_GENERATION_LINK} ]]
[[ -d ${ORIGINAL_SYSTEM_STORE_DIR} ]]
[[ -x ${ORIGINAL_SYSTEM_STORE_DIR}/bin/switch-to-configuration ]]
[[ -r ${ORIGINAL_SYSTEM_STORE_DIR}/kernel ]]
[[ -r ${ORIGINAL_SYSTEM_STORE_DIR}/initrd ]]
readlink -z -- "${ORIGINAL_GENERATION_LINK}" \
  >"${WORK}/original-generation-link-target"
printf '%s\0' "${ORIGINAL_SYSTEM_PATH}" \
  >"${WORK}/expected-original-generation-link-target"
cmp -s -- \
  "${WORK}/original-generation-link-target" \
  "${WORK}/expected-original-generation-link-target"

if ! ESP_DEVICE=$(readlink -e "/dev/disk/by-uuid/${ESP_UUID}"); then
  printf 'Refusing: cannot resolve the EFI system partition\n' >&2
  exit 1
fi
[[ -b ${ESP_DEVICE} ]]
if ! ACTUAL_ESP_UUID=$(blkid -s UUID -o value "${ESP_DEVICE}"); then
  printf 'Refusing: cannot read the EFI system partition UUID\n' >&2
  exit 1
fi
[[ ${ACTUAL_ESP_UUID} == "${ESP_UUID}" ]]
assert_device_unmounted "${ESP_DEVICE}"
assert_not_mountpoint "${ESP}"
assert_empty_directory "${ESP}"
mount -t vfat -o ro,nodev,nosuid,noexec "${ESP_DEVICE}" "${ESP}"

if ! awk -v generation="${ORIGINAL_GENERATION}" '
  BEGIN { prefix = "menuentry \"NixOS - Configuration " generation " (" }
  index($0, prefix) == 1 { print }
' "${ESP}/grub/grub.cfg" >"${WORK}/original-grub-generation-headers"; then
  printf 'Refusing: cannot count original GRUB generation headers\n' >&2
  exit 1
fi
mapfile -t ORIGINAL_GRUB_GENERATION_HEADERS \
  <"${WORK}/original-grub-generation-headers"
(( ${#ORIGINAL_GRUB_GENERATION_HEADERS[@]} == 1 ))
if ! awk -v generation="${ORIGINAL_GENERATION}" '
  BEGIN { prefix = "menuentry \"NixOS - Configuration " generation " (" }
  index($0, prefix) == 1 { found = 1; inside = 1 }
  inside { print }
  inside && $0 == "}" { closed = 1; exit }
  END { if (!found || !closed) exit 1 }
' "${ESP}/grub/grub.cfg" >"${WORK}/original-grub-entry"; then
  printf 'Refusing: cannot isolate original GRUB generation %s\n' \
    "${ORIGINAL_GENERATION}" >&2
  exit 1
fi
grep -Fq -- "init=${ORIGINAL_SYSTEM_PATH}/init " \
  "${WORK}/original-grub-entry"
if ! sed -nE \
  's#^[[:space:]]*(linux|initrd)[[:space:]]+\([^)]*\)/+([^[:space:]]+).*#\1 \2#p' \
  "${WORK}/original-grub-entry" >"${WORK}/original-grub-boot-files"; then
  printf 'Refusing: cannot parse original GRUB boot artifacts\n' >&2
  exit 1
fi
mapfile -t ORIGINAL_GRUB_BOOT_FILES <"${WORK}/original-grub-boot-files"
(( ${#ORIGINAL_GRUB_BOOT_FILES[@]} == 2 ))
declare -A ORIGINAL_GRUB_BOOT_KIND_SEEN=()
declare -A ORIGINAL_GRUB_BOOT_PATHS=()
for ORIGINAL_GRUB_BOOT_RECORD in "${ORIGINAL_GRUB_BOOT_FILES[@]}"; do
  read -r ORIGINAL_GRUB_BOOT_KIND ORIGINAL_GRUB_BOOT_PATH ORIGINAL_GRUB_BOOT_EXTRA \
    <<<"${ORIGINAL_GRUB_BOOT_RECORD}"
  [[ -z ${ORIGINAL_GRUB_BOOT_EXTRA} ]]
  [[ ${ORIGINAL_GRUB_BOOT_KIND} == linux || ${ORIGINAL_GRUB_BOOT_KIND} == initrd ]]
  [[ -z ${ORIGINAL_GRUB_BOOT_KIND_SEEN[${ORIGINAL_GRUB_BOOT_KIND}]+x} ]]
  [[ ${ORIGINAL_GRUB_BOOT_PATH} =~ ^kernels/[0-9A-Za-z._+-]+$ ]]
  [[ -f ${ESP}/${ORIGINAL_GRUB_BOOT_PATH} ]]
  ORIGINAL_GRUB_BOOT_KIND_SEEN["${ORIGINAL_GRUB_BOOT_KIND}"]=1
  ORIGINAL_GRUB_BOOT_PATHS["${ORIGINAL_GRUB_BOOT_KIND}"]=${ORIGINAL_GRUB_BOOT_PATH}
done
[[ -n ${ORIGINAL_GRUB_BOOT_KIND_SEEN[linux]+x} ]]
[[ -n ${ORIGINAL_GRUB_BOOT_KIND_SEEN[initrd]+x} ]]
cmp -s -- "${ORIGINAL_SYSTEM_STORE_DIR}/kernel" \
  "${ESP}/${ORIGINAL_GRUB_BOOT_PATHS[linux]}"
cmp -s -- "${ORIGINAL_SYSTEM_STORE_DIR}/initrd" \
  "${ESP}/${ORIGINAL_GRUB_BOOT_PATHS[initrd]}"

ROOT_OLD="${TOP}/@.pre-restore-${RESTORE_TAG}"
HOME_OLD="${TOP}/@home.pre-restore-${RESTORE_TAG}"
RESTORED_ROOT_UUID=$(subvolume_uuid "${TOP}/@")
RESTORED_HOME_UUID=$(subvolume_uuid "${TOP}/@home")
ORIGINAL_ROOT_UUID=$(subvolume_uuid "${ROOT_OLD}")
ORIGINAL_HOME_UUID=$(subvolume_uuid "${HOME_OLD}")
[[ ${RESTORED_ROOT_UUID} != "${ORIGINAL_ROOT_UUID}" ]]
[[ ${RESTORED_HOME_UUID} != "${ORIGINAL_HOME_UUID}" ]]
ROLLBACK_TAG="$(date -u +%Y%m%dT%H%M%SZ)"
ROOT_REJECTED="${TOP}/@.rejected-${ROLLBACK_TAG}"
HOME_REJECTED="${TOP}/@home.rejected-${ROLLBACK_TAG}"

for SUBVOLUME in "${TOP}/@" "${TOP}/@home" "${ROOT_OLD}" "${HOME_OLD}"; do
  [[ -d ${SUBVOLUME} && ! -L ${SUBVOLUME} ]]
  btrfs subvolume show "${SUBVOLUME}" >/dev/null
done
for PATH_TO_CREATE in "${ROOT_REJECTED}" "${HOME_REJECTED}"; do
  [[ ! -e ${PATH_TO_CREATE} && ! -L ${PATH_TO_CREATE} ]]
done

printf 'restore original root from: %s\nrestore original home from: %s\n' \
  "${ROOT_OLD}" "${HOME_OLD}"
printf 'Record before the reverse rename:\nROLLBACK_TAG=%s\n' "${ROLLBACK_TAG}"
printf 'RESTORED_ROOT_UUID=%s\nRESTORED_HOME_UUID=%s\n' \
  "${RESTORED_ROOT_UUID}" "${RESTORED_HOME_UUID}"
printf 'ORIGINAL_ROOT_UUID=%s\nORIGINAL_HOME_UUID=%s\n' \
  "${ORIGINAL_ROOT_UUID}" "${ORIGINAL_HOME_UUID}"
read -r -p "Type ROLLBACK ${RESTORE_TAG} to continue: " CONFIRMATION
[[ ${CONFIRMATION} == "ROLLBACK ${RESTORE_TAG}" ]]

ROOT_REJECTED_MOVED=0
ROOT_OLD_INSTALLED=0
HOME_REJECTED_MOVED=0
HOME_OLD_INSTALLED=0

reverse_incomplete_rollback() {
  local status=$1 reverse_failed=0
  trap - ERR INT TERM HUP
  set +e

  if (( HOME_OLD_INSTALLED )); then
    mv --no-copy --update=none-fail -T -- \
      "${TOP}/@home" "${HOME_OLD}" || reverse_failed=1
  fi
  if (( HOME_REJECTED_MOVED )); then
    mv --no-copy --update=none-fail -T -- \
      "${HOME_REJECTED}" "${TOP}/@home" || reverse_failed=1
  fi
  if (( ROOT_OLD_INSTALLED )); then
    mv --no-copy --update=none-fail -T -- \
      "${TOP}/@" "${ROOT_OLD}" || reverse_failed=1
  fi
  if (( ROOT_REJECTED_MOVED )); then
    mv --no-copy --update=none-fail -T -- \
      "${ROOT_REJECTED}" "${TOP}/@" || reverse_failed=1
  fi
  btrfs filesystem sync "${TOP}" || reverse_failed=1

  if (( reverse_failed )); then
    printf 'Automatic reversal was incomplete. Do not reboot; inspect only the exact paths printed above.\n' >&2
  else
    printf 'The interrupted rollback was reversed; the restored pair is active again.\n' >&2
  fi
  exit "${status}"
}

rename_for_rollback() {
  local source=$1 destination=$2 flag_name=$3 status

  trap '' INT TERM HUP
  if mv --no-copy --update=none-fail -T -- "${source}" "${destination}"; then
    printf -v "${flag_name}" '%s' 1
    trap 'reverse_incomplete_rollback 130' INT TERM HUP
    return 0
  else
    status=$?
    trap 'reverse_incomplete_rollback 130' INT TERM HUP
    return "${status}"
  fi
}

trap 'reverse_incomplete_rollback $?' ERR
trap 'reverse_incomplete_rollback 130' INT TERM HUP

rename_for_rollback "${TOP}/@" "${ROOT_REJECTED}" ROOT_REJECTED_MOVED
rename_for_rollback "${ROOT_OLD}" "${TOP}/@" ROOT_OLD_INSTALLED
rename_for_rollback "${TOP}/@home" "${HOME_REJECTED}" HOME_REJECTED_MOVED
rename_for_rollback "${HOME_OLD}" "${TOP}/@home" HOME_OLD_INSTALLED

btrfs filesystem sync "${TOP}"
for ACTIVE in "${TOP}/@" "${TOP}/@home"; do
  btrfs subvolume show "${ACTIVE}" >/dev/null
  [[ $(btrfs property get -ts "${ACTIVE}" ro) == 'ro=false' ]]
done
for RETAINED in "${ROOT_REJECTED}" "${HOME_REJECTED}"; do
  btrfs subvolume show "${RETAINED}" >/dev/null
done
trap - ERR INT TERM HUP
```

This retains the rejected restored pair under exact `.rejected-*` names. Never
use a wildcard `mv`, `rm`, or `btrfs subvolume delete` while resolving an
interrupted recovery.

### Recover an interrupted reverse restore

If power failed during the four reverse-renames above, do not boot and do not
move one member manually. Boot rescue media and repeat only section 1 through
the top-level mount and identity checks—not the active nested-subvolume
subsection. Run the following with the exact values printed immediately before
the reverse rename. Its default is the complete restored pair that was active
before the reverse operation began.

```bash
RESTORE_TAG='REPLACE_WITH_THE_EXACT_ORIGINAL_RESTORE_TAG'
ROLLBACK_TAG='REPLACE_WITH_THE_RECORDED_ROLLBACK_TAG'
RESTORED_ROOT_UUID='REPLACE_WITH_RECORDED_RESTORED_ROOT_UUID'
RESTORED_HOME_UUID='REPLACE_WITH_RECORDED_RESTORED_HOME_UUID'
ORIGINAL_ROOT_UUID='REPLACE_WITH_RECORDED_ORIGINAL_ROOT_UUID'
ORIGINAL_HOME_UUID='REPLACE_WITH_RECORDED_ORIGINAL_HOME_UUID'
[[ ${RESTORE_TAG} =~ ^[0-9]{8}T[0-9]{6}Z-g[1-9][0-9]*$ ]]
[[ ${ROLLBACK_TAG} =~ ^[0-9]{8}T[0-9]{6}Z$ ]]
for RECORDED_UUID in \
  "${RESTORED_ROOT_UUID}" "${RESTORED_HOME_UUID}" \
  "${ORIGINAL_ROOT_UUID}" "${ORIGINAL_HOME_UUID}"; do
  [[ ${RECORDED_UUID} =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]
done
RESTORED_ROOT_UUID=${RESTORED_ROOT_UUID,,}
RESTORED_HOME_UUID=${RESTORED_HOME_UUID,,}
ORIGINAL_ROOT_UUID=${ORIGINAL_ROOT_UUID,,}
ORIGINAL_HOME_UUID=${ORIGINAL_HOME_UUID,,}

ACTIVE_ROOT="${TOP}/@"
ACTIVE_HOME="${TOP}/@home"
ROOT_OLD="${TOP}/@.pre-restore-${RESTORE_TAG}"
HOME_OLD="${TOP}/@home.pre-restore-${RESTORE_TAG}"
ROOT_REJECTED="${TOP}/@.rejected-${ROLLBACK_TAG}"
HOME_REJECTED="${TOP}/@home.rejected-${ROLLBACK_TAG}"

classify_reverse_member() {
  local active=$1 old=$2 rejected=$3
  local restored_uuid=$4 original_uuid=$5 result_name=$6
  local path uuid restored_count=0 original_count=0
  local restored_path='' original_path=''

  for path in "${active}" "${old}" "${rejected}"; do
    [[ -e ${path} || -L ${path} ]] || continue
    assert_subvolume_directory "${path}"
    uuid=$(subvolume_uuid "${path}")
    if [[ ${uuid} == "${restored_uuid}" ]]; then
      restored_count=$((restored_count + 1))
      restored_path=${path}
    elif [[ ${uuid} == "${original_uuid}" ]]; then
      original_count=$((original_count + 1))
      original_path=${path}
    else
      printf 'Refusing: unexpected UUID %s at %s\n' "${uuid}" "${path}" >&2
      return 1
    fi
  done
  (( restored_count == 1 && original_count == 1 ))
  printf -v "${result_name}" '%s\t%s' "${restored_path}" "${original_path}"
}

classify_reverse_member \
  "${ACTIVE_ROOT}" "${ROOT_OLD}" "${ROOT_REJECTED}" \
  "${RESTORED_ROOT_UUID}" "${ORIGINAL_ROOT_UUID}" ROOT_REVERSE_STATE
classify_reverse_member \
  "${ACTIVE_HOME}" "${HOME_OLD}" "${HOME_REJECTED}" \
  "${RESTORED_HOME_UUID}" "${ORIGINAL_HOME_UUID}" HOME_REVERSE_STATE
IFS=$'\t' read -r ROOT_RESTORED_PATH ROOT_ORIGINAL_PATH \
  <<<"${ROOT_REVERSE_STATE}"
IFS=$'\t' read -r HOME_RESTORED_PATH HOME_ORIGINAL_PATH \
  <<<"${HOME_REVERSE_STATE}"
printf 'root restored=%s original=%s\nhome restored=%s original=%s\n' \
  "${ROOT_RESTORED_PATH}" "${ROOT_ORIGINAL_PATH}" \
  "${HOME_RESTORED_PATH}" "${HOME_ORIGINAL_PATH}"

read -r -p "Type RESTORE-RESTORED-PAIR ${ROLLBACK_TAG}: " \
  REVERSE_CONFIRMATION
[[ ${REVERSE_CONFIRMATION} == "RESTORE-RESTORED-PAIR ${ROLLBACK_TAG}" ]]

put_restored_member_back() {
  local active=$1 old_name=$2 restored_path=$3 original_path=$4
  local restored_uuid=$5 original_uuid=$6

  if [[ ${restored_path} != "${active}" ]]; then
    if [[ -e ${active} || -L ${active} ]]; then
      assert_subvolume_uuid "${active}" "${original_uuid}"
      [[ ! -e ${old_name} && ! -L ${old_name} ]]
      mv --no-copy --update=none-fail -T -- "${active}" "${old_name}"
    fi
    mv --no-copy --update=none-fail -T -- "${restored_path}" "${active}"
  fi
  assert_subvolume_uuid "${active}" "${restored_uuid}"
  assert_subvolume_uuid "${old_name}" "${original_uuid}"
}

trap '' INT TERM HUP
put_restored_member_back \
  "${ACTIVE_ROOT}" "${ROOT_OLD}" \
  "${ROOT_RESTORED_PATH}" "${ROOT_ORIGINAL_PATH}" \
  "${RESTORED_ROOT_UUID}" "${ORIGINAL_ROOT_UUID}"
put_restored_member_back \
  "${ACTIVE_HOME}" "${HOME_OLD}" \
  "${HOME_RESTORED_PATH}" "${HOME_ORIGINAL_PATH}" \
  "${RESTORED_HOME_UUID}" "${ORIGINAL_HOME_UUID}"
btrfs filesystem sync "${TOP}"
assert_subvolume_uuid "${ACTIVE_ROOT}" "${RESTORED_ROOT_UUID}"
assert_subvolume_uuid "${ACTIVE_HOME}" "${RESTORED_HOME_UUID}"
trap - INT TERM HUP
```

This state machine is re-runnable after another outage: it moves any active
original back to its exact `.pre-restore-*` name, then reinstalls both recorded
restored UUIDs. It never deletes either pair. After it completes, boot and
verify the selected rollback `GENERATION`, not `ORIGINAL_GENERATION`. Terminate
this rescue path now:

```bash
umount "${TOP}"
reboot
```

Explicitly select the rollback `GENERATION` in GRUB and run section 6. Do
**not** execute the normal completed-reverse path below. Start a fresh reverse
restore only after the restored pair and rollback closure have passed that
complete verification.

### Normal reverse completed without interruption

Unmount the exact mounts and reboot:

```bash
umount "${ESP}"
umount "${TOP}"
reboot
```

In GRUB, explicitly select the recorded **NixOS - Configuration
`ORIGINAL_GENERATION`**. Restoring the original mutable pair while continuing
to boot the rollback closure would leave system and data lifecycles mismatched.
After booting, enter a new root login shell:

```bash
sudo -i
```

At the root prompt, start the new fail-closed Bash verification session:

```bash
if [ -z "${BASH_VERSION:-}" ]; then
  printf 'Refusing: start Bash before continuing\n' >&2
  exit 1
fi
set -Eeuo pipefail
export LC_ALL=C

ORIGINAL_GENERATION='REPLACE_WITH_RECORDED_ORIGINAL_GENERATION'
ORIGINAL_SYSTEM_PATH='REPLACE_WITH_RECORDED_ORIGINAL_SYSTEM_PATH'
[[ ${ORIGINAL_GENERATION} =~ ^[1-9][0-9]*$ ]]
[[ ${ORIGINAL_SYSTEM_PATH} =~ ^/nix/store/[0-9a-z]{32}-[^/]+$ ]]
if ! ORIGINAL_SELECTED_SYSTEM=$(readlink -e \
  "/nix/var/nix/profiles/system-${ORIGINAL_GENERATION}-link"); then
  printf 'Refusing: the original system generation is not retained\n' >&2
  exit 1
fi
if ! RUNNING_SYSTEM=$(readlink -e /run/current-system); then
  printf 'Refusing: cannot identify the running system\n' >&2
  exit 1
fi
[[ ${ORIGINAL_SELECTED_SYSTEM} == "${ORIGINAL_SYSTEM_PATH}" ]]
[[ ${RUNNING_SYSTEM} == "${ORIGINAL_SYSTEM_PATH}" ]]

nix-env --switch-generation "${ORIGINAL_GENERATION}" \
  -p /nix/var/nix/profiles/system
if ! CURRENT_PROFILE_SYSTEM=$(readlink -e /nix/var/nix/profiles/system); then
  printf 'Refusing: cannot identify the current system profile\n' >&2
  exit 1
fi
[[ ${CURRENT_PROFILE_SYSTEM} == "${RUNNING_SYSTEM}" ]]
"${RUNNING_SYSTEM}/bin/switch-to-configuration" switch
"${RUNNING_SYSTEM}/sw/bin/nixos-generation-snapshot" verify-current
```

The retained `.pre-restore-*` or `.rejected-*` pairs can consume space as their
contents diverge. Remove them only in a later, separately audited maintenance
operation after off-device backup and explicit identification of each exact
subvolume; deletion is intentionally outside this emergency runbook.
