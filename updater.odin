package main

import "core:fmt"
import "core:os"
import "core:os/os2"
import "core:strings"
import "core:path/filepath"
import mz "miniz"
import tfd "tinyfiledialogs"

Updater :: proc() {
    pre_cleanup :: proc() {
        if ODIN_OS == .Linux {
            os2.remove_all("./usr")
        }
        os2.remove_all("./Throne_update")
    }

    // find update package
    update_package_path: string
    if os.exists("./Throne.zip") {
        update_package_path = "./Throne.zip"
    } else {
        tfd.messageBox("Throne Updater", "No update", "ok", "error", 0)
        os.exit(1)
    }
    fmt.println("updating from", update_package_path)

    dir, err := os2.getwd(context.temp_allocator)
    if err != nil {
        tfd.messageBox("Throne Updater", cstring(raw_data(fmt.tprintf("Failed to get working directory: %v", err))), "ok", "error", 0)
        os.exit(1)
    }

    // // extract update package
    if strings.has_suffix(update_package_path, ".zip") {
        pre_cleanup()
        
        if !unpack(update_package_path, "Throne_update") {
            tfd.messageBox("Throne Updater", "Failed to extract zip", "ok", "error", 0)
            os.exit(1)
        }
    }

    // remove old files
    remove_all("./*.dll")
    remove_all("./*.dmp")

    // update move
    if !os.exists("./Throne_update/Throne") {
    	tfd.messageBox("Throne Updater", "Throne_update/Throne does not exist", "ok", "error", 0)
    	os.exit(1)
    }
    err_mv := mv("./Throne_update/Throne", "./")
    if err_mv != nil {
        tfd.messageBox("Throne Updater", cstring(raw_data(fmt.tprintf("Update failed. Please close the running instance and run the updater again.\nError: %v", err_mv))), "ok", "error", 0)
        os.exit(1)
    }

    os2.remove_all("./Throne.zip")
    os2.remove_all("./Throne_update")
}

mv :: proc(src, dst: string) -> os.Error {
    if os.is_dir(src) {
        directory, err := os.open(src)
        defer os.close(directory)
        if err != nil {
            return err
        }
        entries, read_dir_err := os.read_dir(directory, -1)
        if read_dir_err != nil {
            return read_dir_err
        }
        defer delete(entries)
        for e, i in entries {
            entry_path := filepath.join({src, e.name})
            target_path := filepath.join({dst, e.name})
            err = mv(entry_path, target_path)
            if err != nil {
                return err
            }
        }
    } else {
        if !os.exists(dst) {
            os2.make_directory_all(filepath.dir(dst))
        }
        err := os.rename(src, dst)
        if err != nil {
            return err
        }
        if ODIN_OS == .Linux {
            os2.chmod(dst, 0o755)
        }
    }
    return nil
}

remove_all :: proc(glob: string) {
    files, err := filepath.glob(glob)
    if err != nil {
        return
    }
    defer delete(files)
    for f in files {
        os.remove(f)
    }
}

unpack :: proc(src, dst: string) -> bool {
    FILE_NAME_BUFFER_SIZE :: 512
    file_name_buffer: [FILE_NAME_BUFFER_SIZE]byte

    data, ok := os.read_entire_file(src)
    if !ok {
        return false
    }
    defer delete(data)

    zip_file: mz.zip_archive
    ok = cast(bool)mz.zip_reader_init_mem(&zip_file, raw_data(data), len(data), 0)
    if !ok {
        return false
    }

    num_files := mz.zip_reader_get_num_files(&zip_file)
    for i in 0..<num_files {
        if mz.zip_reader_is_file_a_directory(&zip_file, i) {
            continue
        }

        mz.zip_reader_get_filename(&zip_file, i, &file_name_buffer[0], FILE_NAME_BUFFER_SIZE)
        file_name := string(cstring(&file_name_buffer[0]))
        dst_filename := filepath.join({dst, file_name}, context.temp_allocator)
        dir := strings.trim_suffix(dst_filename, filepath.base(dst_filename))
        if !os.exists(dir) {
            os2.make_directory_all(dir)
        }
        if !mz.zip_reader_extract_to_file(&zip_file, i, dst_filename, 0) {
            fmt.println("BAD ERROR")
        }
    }

    result := cast(bool)mz.zip_end(&zip_file)
    return result
}

main :: proc() {
    Updater()
    if ODIN_OS == .Windows {
        _, _ = os2.process_start({command = {"./Throne.exe"},})
    } else {
        _, _ = os2.process_start({command = {"./Throne"},})
    }

}