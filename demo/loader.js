let input, output, display, mem, backend, gameFile

function addElement(eType, eClass, eContent, eParent) {
    let element = document.createElement(eType)
    element.classList.add(eClass)
    element.innerHTML = eContent
    eParent.appendChild(element)
    return element
}

async function getInput() {
    let styledSpace = '<span style="color:green;">&nbsp;</span>'
    if (output.innerHTML.endsWith(' ')) {
        output.innerHTML = output.innerHTML.slice(0, -1) + styledSpace
    } else output.innerHTML += styledSpace
    input = addElement('span', 'FlaxoInput', '', output)
    input.contentEditable = "true"
    input.spellcheck = false
    input.focus()

    return new Promise((resolve) => {
        let keyScanner = (key) => {
            if (key.code == 'Enter') {
                key.preventDefault()
                input.removeEventListener("keydown", keyScanner)
                input.contentEditable = "false"
                resolve(input.innerHTML)
            }
        }
        input.addEventListener("keydown", keyScanner)
    })
}

let imports = {
    env: {
        output_message: (ptr, len) => {
            let message = new TextDecoder().decode(mem.subarray(ptr, ptr + len))
            //console.log(message);
            for (let chunk of message.split('\n'))
                output = addElement('p', 'FlaxoOutput', chunk, display)
        },
        read_input: async (ptr, len, callback) => {
            let command = (await getInput()).trim()
            command = command.replace(/&nbsp;/g, '');
            new TextEncoder().encodeInto(command, mem.subarray(ptr, ptr + len))
            backend.__indirect_function_table.get(callback)(command.length)
        },
        display_bitmap: (image, x, y) => {
            console.log(`Display bitmap ${image&0xFFFF} at (${x&0xFFFF}, ${y&0xFFFF})`)
        },
        toggle_image: (state, extra) => {
            if (state) console.log("Show image", extra)
            else       console.log("Hide image")
        },
        JSLoad: async (file_no, address, callback) => {
            console.log('Loading part', file_no);
            gameFile = gameFile.replace('1', file_no);
            let gameData = await fetch(gameFile)
                .then(result => result.arrayBuffer())
                .then(buffer => new Uint8Array(buffer))
            mem.set(gameData, address)
            backend.__indirect_function_table.get(callback)(gameData.length);
        },
        console_log: (value) => {
            console.log('Success', value);
        },
        log_char: (char) => {
            console.log('Char', String.fromCharCode(char));
        },
        log_message: (ptr, len) => {
            let message = new TextDecoder().decode(mem.subarray(ptr, ptr + len))
            console.log(message);
        },
        random_bits: (num_bits) => {
            const random_number = Math.floor(Math.random()*(2**num_bits));
            return random_number;
        }
    }
}

export async function loadL9(file, version, screen, pictureFolder, skipIntro = false) {
    display = screen
    gameFile = file
    backend = (await WebAssembly.instantiateStreaming(
                        fetch("./l9.wasm"), 
                        imports
                    )).instance.exports
    mem = new Uint8Array(backend.memory.buffer);
    backend.start(version);
}
