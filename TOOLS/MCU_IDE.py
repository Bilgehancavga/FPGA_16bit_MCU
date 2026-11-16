#!/usr/bin/env python3
from __future__ import annotations

import threading
import tkinter as tk
from tkinter import filedialog, messagebox, ttk
from tkinter.scrolledtext import ScrolledText
from pathlib import Path

import assembler_load as asm

APP_TITLE = "Bilge MCU IDE"


class MCUIDE(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title(APP_TITLE)
        self.geometry("1180x780")
        self.minsize(900, 600)

        self.current_file: Path | None = None
        self.modified = False

        self.port_var = tk.StringVar(value=getattr(asm, "DEFAULT_UART_PORT", "COM3"))
        self.baud_var = tk.StringVar(value=str(getattr(asm, "DEFAULT_BAUD_RATE", 9600)))
        self.status_var = tk.StringVar(value="Ready")

        self._build_menu()
        self._build_toolbar()
        self._build_editor()
        self._build_console()
        self._build_statusbar()
        self._bind_shortcuts()

        self.protocol("WM_DELETE_WINDOW", self.on_close)
        self._update_title()
        self.editor.focus_set()

    def _build_menu(self):
        menubar = tk.Menu(self)

        file_menu = tk.Menu(menubar, tearoff=False)
        file_menu.add_command(label="New", accelerator="Ctrl+N", command=self.new_file)
        file_menu.add_command(label="Open...", accelerator="Ctrl+O", command=self.open_file)
        file_menu.add_command(label="Save", accelerator="Ctrl+S", command=self.save_file)
        file_menu.add_command(label="Save As...", accelerator="Ctrl+Shift+S", command=self.save_as)
        file_menu.add_separator()
        file_menu.add_command(label="Exit", command=self.on_close)
        menubar.add_cascade(label="File", menu=file_menu)

        edit_menu = tk.Menu(menubar, tearoff=False)
        edit_menu.add_command(label="Undo", accelerator="Ctrl+Z", command=lambda: self._event(self.editor, "<<Undo>>"))
        edit_menu.add_command(label="Redo", accelerator="Ctrl+Y", command=lambda: self._event(self.editor, "<<Redo>>"))
        edit_menu.add_separator()
        edit_menu.add_command(label="Cut", accelerator="Ctrl+X", command=lambda: self._event(self.editor, "<<Cut>>"))
        edit_menu.add_command(label="Copy", accelerator="Ctrl+C", command=lambda: self._event(self.editor, "<<Copy>>"))
        edit_menu.add_command(label="Paste", accelerator="Ctrl+V", command=lambda: self._event(self.editor, "<<Paste>>"))
        edit_menu.add_separator()
        edit_menu.add_command(label="Select All", accelerator="Ctrl+A", command=self.select_all)
        menubar.add_cascade(label="Edit", menu=edit_menu)

        mcu_menu = tk.Menu(menubar, tearoff=False)
        mcu_menu.add_command(label="Run / Compile", accelerator="F5", command=self.run_compile)
        mcu_menu.add_command(label="Load", accelerator="F6", command=self.load_program)
        mcu_menu.add_command(label="Reload", accelerator="F7", command=self.reload_program)
        menubar.add_cascade(label="MCU", menu=mcu_menu)

        self.config(menu=menubar)

    def _build_toolbar(self):
        bar = ttk.Frame(self, padding=(8, 6))
        bar.pack(fill="x")

        ttk.Button(bar, text="New", command=self.new_file).pack(side="left", padx=3)
        ttk.Button(bar, text="Open", command=self.open_file).pack(side="left", padx=3)
        ttk.Button(bar, text="Save", command=self.save_file).pack(side="left", padx=3)

        ttk.Separator(bar, orient="vertical").pack(side="left", fill="y", padx=8)

        ttk.Button(bar, text="RUN", command=self.run_compile).pack(side="left", padx=3)
        ttk.Button(bar, text="LOAD", command=self.load_program).pack(side="left", padx=3)
        ttk.Button(bar, text="RELOAD", command=self.reload_program).pack(side="left", padx=3)

        ttk.Separator(bar, orient="vertical").pack(side="left", fill="y", padx=8)

        ttk.Label(bar, text="Port:").pack(side="left")
        self.port_combo = ttk.Combobox(bar, textvariable=self.port_var, width=11)
        self.port_combo.pack(side="left", padx=(4, 8))
        self.refresh_ports()

        ttk.Label(bar, text="Baud:").pack(side="left")
        ttk.Entry(bar, textvariable=self.baud_var, width=9).pack(side="left", padx=(4, 0))

    def _build_editor(self):
        frame = ttk.Frame(self, padding=(8, 0, 8, 6))
        frame.pack(fill="both", expand=True)

        self.editor = ScrolledText(
            frame,
            wrap="none",
            undo=True,
            maxundo=-1,
            font=("Consolas", 12),
            tabs=("2c",),
        )
        self.editor.pack(fill="both", expand=True)
        self.editor.bind("<<Modified>>", self._on_modified)

        # Sağ tık menüsü: kopyala/yapıştır dahil.
        self.context_menu = tk.Menu(self, tearoff=False)
        self.context_menu.add_command(label="Undo", command=lambda: self._event(self.editor, "<<Undo>>"))
        self.context_menu.add_command(label="Redo", command=lambda: self._event(self.editor, "<<Redo>>"))
        self.context_menu.add_separator()
        self.context_menu.add_command(label="Cut", command=lambda: self._event(self.editor, "<<Cut>>"))
        self.context_menu.add_command(label="Copy", command=lambda: self._event(self.editor, "<<Copy>>"))
        self.context_menu.add_command(label="Paste", command=lambda: self._event(self.editor, "<<Paste>>"))
        self.context_menu.add_separator()
        self.context_menu.add_command(label="Select All", command=self.select_all)
        self.editor.bind("<Button-3>", self._show_context_menu)

    def _build_console(self):
        frame = ttk.LabelFrame(self, text="Build / Upload Output", padding=6)
        frame.pack(fill="both", padx=8, pady=(0, 6))

        self.console = ScrolledText(
            frame,
            height=12,
            wrap="none",
            font=("Consolas", 10),
            state="disabled",
        )
        self.console.pack(fill="both", expand=True)

    def _build_statusbar(self):
        bar = ttk.Frame(self, padding=(8, 3))
        bar.pack(fill="x")
        ttk.Label(bar, textvariable=self.status_var).pack(side="left")

    def _bind_shortcuts(self):
        self.bind("<Control-n>", lambda e: self.new_file())
        self.bind("<Control-o>", lambda e: self.open_file())
        self.bind("<Control-s>", lambda e: self.save_file())
        self.bind("<Control-Shift-S>", lambda e: self.save_as())
        self.bind("<F5>", lambda e: self.run_compile())
        self.bind("<F6>", lambda e: self.load_program())
        self.bind("<F7>", lambda e: self.reload_program())

        self.editor.bind("<Control-x>", lambda e: self._event(self.editor, "<<Cut>>"))
        self.editor.bind("<Control-c>", lambda e: self._event(self.editor, "<<Copy>>"))
        self.editor.bind("<Control-v>", lambda e: self._event(self.editor, "<<Paste>>"))
        self.editor.bind("<Control-a>", self.select_all)

    @staticmethod
    def _event(widget, sequence):
        widget.event_generate(sequence)
        return "break"

    def select_all(self, event=None):
        self.editor.tag_add("sel", "1.0", "end-1c")
        self.editor.mark_set("insert", "1.0")
        self.editor.see("insert")
        return "break"

    def _show_context_menu(self, event):
        self.editor.focus_set()
        self.context_menu.tk_popup(event.x_root, event.y_root)

    def _on_modified(self, _event=None):
        if self.editor.edit_modified():
            self.modified = True
            self.editor.edit_modified(False)
            self._update_title()

    def _update_title(self):
        name = self.current_file.name if self.current_file else "Untitled.asm"
        star = " *" if self.modified else ""
        self.title(f"{APP_TITLE} - {name}{star}")

    def get_source_lines(self):
        return self.editor.get("1.0", "end-1c").splitlines()

    def _confirm_discard(self) -> bool:
        if not self.modified:
            return True
        answer = messagebox.askyesnocancel("Unsaved changes", "Save changes before continuing?")
        if answer is None:
            return False
        if answer:
            return bool(self.save_file())
        return True

    def new_file(self):
        if not self._confirm_discard():
            return
        self.editor.delete("1.0", "end")
        self.current_file = None
        self.modified = False
        self.editor.edit_modified(False)
        self._update_title()
        self.clear_console()
        self.status_var.set("New file")

    def open_file(self):
        if not self._confirm_discard():
            return
        path = filedialog.askopenfilename(
            title="Open assembly file",
            filetypes=[("Assembly files", "*.asm"), ("Text files", "*.txt"), ("All files", "*.*")],
        )
        if not path:
            return
        try:
            text = Path(path).read_text(encoding="utf-8")
        except Exception as exc:
            messagebox.showerror("Open failed", str(exc))
            return

        self.editor.delete("1.0", "end")
        self.editor.insert("1.0", text)
        self.current_file = Path(path)
        self.modified = False
        self.editor.edit_modified(False)
        self._update_title()
        self.status_var.set(f"Opened {self.current_file.name}")

    def save_file(self):
        if self.current_file is None:
            return self.save_as()
        try:
            self.current_file.write_text(self.editor.get("1.0", "end-1c"), encoding="utf-8")
        except Exception as exc:
            messagebox.showerror("Save failed", str(exc))
            return False
        self.modified = False
        self.editor.edit_modified(False)
        self._update_title()
        self.status_var.set(f"Saved {self.current_file.name}")
        return True

    def save_as(self):
        path = filedialog.asksaveasfilename(
            title="Save assembly file",
            defaultextension=".asm",
            filetypes=[("Assembly files", "*.asm"), ("Text files", "*.txt"), ("All files", "*.*")],
        )
        if not path:
            return False
        self.current_file = Path(path)
        return self.save_file()

    def clear_console(self):
        self.console.configure(state="normal")
        self.console.delete("1.0", "end")
        self.console.configure(state="disabled")

    def append_console(self, text: str):
        self.console.configure(state="normal")
        self.console.insert("end", text)
        self.console.see("end")
        self.console.configure(state="disabled")

    def _assemble_editor(self):
        return asm.assemble(self.get_source_lines())

    def run_compile(self):
        self._start_job("RUN", self._job_run)

    def load_program(self):
        self._start_job("LOAD", lambda: self._job_upload(False))

    def reload_program(self):
        self._start_job("RELOAD", lambda: self._job_upload(True))

    def _start_job(self, name, job):
        self.clear_console()
        self.status_var.set(f"{name}...")
        self.append_console(f"{name} started...\n\n")
        threading.Thread(target=self._thread_wrapper, args=(name, job), daemon=True).start()

    def _thread_wrapper(self, name, job):
        try:
            result = job()
            self.after(0, lambda result=result: self._job_success(name, result))
        except asm.AssemblyError as exc:
            # Format and capture the error before leaving the except block.
            error_text = exc.pretty()
            self.after(0, lambda error_text=error_text: self._job_error(name, error_text))
        except Exception as exc:
            error_text = str(exc)
            self.after(0, lambda error_text=error_text: self._job_error(name, error_text))

    def _job_run(self):
        encoded, labels = self._assemble_editor()
        listing = asm.listing_text(encoded, labels)

        hex_path = None
        if self.current_file is not None:
            hex_path = self.current_file.with_suffix(".hex")
            hex_path.write_text(asm.hex_output(encoded), encoding="ascii")

        extra = f"\nHEX output: {hex_path}\n" if hex_path else ""
        return listing + extra

    def _job_upload(self, send_load_packet: bool):
        encoded, labels = self._assemble_editor()

        port = self.port_var.get().strip()
        if not port:
            raise RuntimeError("COM port is empty.")

        try:
            baud = int(self.baud_var.get().strip())
        except ValueError:
            raise RuntimeError("Baud rate must be an integer.")

        asm.upload_packets(encoded, port, baud, send_load_packet=send_load_packet)
        listing = asm.listing_text(encoded, labels)

        if send_load_packet:
            msg = (f"\nRELOAD SUCCESS: LOAD packet + {len(encoded)} instruction(s) "
                   f"+ RUN packet sent to {port} @ {baud} baud.\n")
        else:
            msg = (f"\nLOAD SUCCESS: {len(encoded)} instruction(s) "
                   f"+ RUN packet sent to {port} @ {baud} baud.\n")
        return listing + msg

    def _job_success(self, name, output):
        self.append_console(output)
        self.status_var.set(f"{name} completed")

    def _job_error(self, name, error):
        self.append_console(f"\nERROR\n{error}\n")
        self.status_var.set(f"{name} failed")

    def refresh_ports(self):
        ports = []
        try:
            from serial.tools import list_ports
            ports = [p.device for p in list_ports.comports()]
        except Exception:
            pass
        if self.port_var.get() and self.port_var.get() not in ports:
            ports.insert(0, self.port_var.get())
        self.port_combo["values"] = ports

    def on_close(self):
        if self._confirm_discard():
            self.destroy()


if __name__ == "__main__":
    MCUIDE().mainloop()
