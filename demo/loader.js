let input, output, display, mem, backend, gameFile

function addElement(eType, eClass, eContent, eParent) {
    let element = document.createElement(eType)
    element.classList.add(eClass)
    element.innerHTML = eContent
    eParent.appendChild(element)
    return element
}

//let cursor_pos = 0;

async function getInput() {
    let styledSpace = '<span class="FlaxoInput">&nbsp;</span>'
    //console.log(output.innerText.slice(-2)+'x');
    //console.log(output.innerHTML.slice(-2)+'x');
    if (output.innerText.endsWith(' ')) { 
           output.innerText = output.innerText.slice(0, -1);
           addElement('span', 'FlaxoInput', '&nbsp;', output);
    }
    // } else {
    //     console.log('Failed');
    // }
        // + styledSpace;
    // } else output.innerHTML += styledSpace
    //if (!output.innerHTML.endsWith(' ')) output.innerHTML += ' '; 
    input = addElement('span', 'FlaxoInput', '', output)
    input.contentEditable = "true"
    input.spellcheck = false
    // const config = {attributes: true, childList: true, subtree: true, characterData: true};
    // const callback = (mutationList, observer) => {
    //     for (const mutation of mutationList) {
    //         console.log(mutation.type);
    //     }
    // };
    // const observer = new MutationObserver(callback);
    // observer.observe(input, config);
    // input.innerText = '_';
    // document.addEventListener('selectionchange', 
    //     function (ev) {
    //         console.log('Change');
    //         let new_pos = document.getSelection().baseOffset;
    //         console.log(new_pos);
    //         if (new_pos != cursor_pos) {
    //             input.innerText = input.innerText.slice(0, cursor_pos) + input.innerText.slice(cursor_pos + 1);
    //             cursor_pos = new_pos;
    //             input.innerText = input.innerText.slice(0, cursor_pos) + '_' + input.innerText.slice(cursor_pos);
    //             document.getSelection().baseOffset = cursor_pos;
    //         }
    //     })
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
            for (let chunk of message.split('\n')) {
                if (chunk.trimEnd().length == 0) continue;
                output = addElement('p', 'FlaxoOutput', chunk, display);
            }
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
