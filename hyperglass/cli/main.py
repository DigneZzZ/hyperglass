"""hyperglass Command Line Interface."""

# Standard Library
import re
import sys
from typing import Annotated, Optional

# Third Party
import typer

# Local
from .echo import echo


cli = typer.Typer(
    name="hyperglass",
    help="hyperglass Command Line Interface",
    no_args_is_help=True,
    rich_markup_mode="rich",
)


def version_callback(value: bool) -> None:
    """Print version and exit."""
    if not value:
        return
    from hyperglass import __version__
    echo.info(__version__)
    raise typer.Exit()


@cli.callback()
def main(
    version: Annotated[
        bool,
        typer.Option(
            "--version", "-v",
            callback=version_callback,
            is_eager=True,
            help="Show hyperglass version and exit.",
        ),
    ] = False,
) -> None:
    """hyperglass - The network looking glass that tries to make the internet better."""
    pass


@cli.command(name="start")
def _start(
    build: Annotated[bool, typer.Option("--build", "-b", help="Build UI before starting")] = False,
    workers: Annotated[Optional[int], typer.Option("--workers", "-w", help="Number of workers")] = None,
) -> None:
    """Start hyperglass"""
    # Project
    from hyperglass.main import run as start_server

    # Local
    from .util import build_ui

    try:
        if build:
            build_complete = build_ui(timeout=180)
            if build_complete:
                start_server(workers)
        else:
            start_server(workers)

    except (KeyboardInterrupt, SystemExit) as err:
        error_message = str(err)
        if (len(error_message)) > 1:
            echo.warning(str(err))
        echo.error("Stopping hyperglass due to keyboard interrupt.")
        raise typer.Exit(0)


@cli.command(name="build-ui")
def _build_ui(
    timeout: Annotated[int, typer.Option("--timeout", "-t", help="Timeout in seconds")] = 180,
) -> None:
    """Create a new UI build."""
    # Local
    from .util import build_ui as do_build_ui

    with echo._console.status(
        f"Starting new UI build with a {timeout} second timeout...", spinner="aesthetic"
    ):
        do_build_ui(timeout=timeout)


@cli.command(name="system-info")
def _system_info() -> None:
    """Get system information for a bug report"""
    # Third Party
    from rich import box
    from rich.panel import Panel
    from rich.table import Table

    # Project
    from hyperglass.util.system_info import get_system_info

    # Local
    from .static import MD_BOX

    data = get_system_info()

    rows = tuple(
        (f"**{title}**", f"`{value!s}`" if mod == "code" else str(value))
        for title, (value, mod) in data.items()
    )

    table = Table("Metric", "Value", box=MD_BOX)
    for title, metric in rows:
        table.add_row(title, metric)
    echo._console.print(
        Panel(
            "Please copy & paste this table in your bug report",
            style="bold yellow",
            expand=False,
            border_style="yellow",
            box=box.HEAVY,
        )
    )
    echo.plain(table)


@cli.command(name="clear-cache")
def _clear_cache() -> None:
    """Clear the Redis cache"""
    # Project
    from hyperglass.state import use_state

    state = use_state()

    try:
        state.clear()
        echo.success("Cleared Redis Cache")

    except Exception as err:
        if not sys.stdout.isatty():
            echo._console.print_exception(show_locals=True)
            raise typer.Exit(1)

        echo.error("Error clearing cache: {!s}", err)
        raise typer.Exit(1)


@cli.command(name="devices")
def _devices(
    search: Annotated[Optional[str], typer.Argument(help="Device ID or Name Search Pattern")] = None,
) -> None:
    """Show all configured devices"""
    # Third Party
    from rich.columns import Columns
    from rich._inspect import Inspect

    # Project
    from hyperglass.state import use_state

    devices = use_state("devices")
    if search is not None:
        pattern = re.compile(search, re.IGNORECASE)
        for device in devices:
            if pattern.match(device.id) or pattern.match(device.name):
                echo._console.print(
                    Inspect(
                        device,
                        title=device.name,
                        docs=False,
                        methods=False,
                        dunder=False,
                        sort=True,
                        all=False,
                        value=True,
                        help=False,
                    )
                )
                raise typer.Exit(0)

    panels = [
        Inspect(
            device,
            title=device.name,
            docs=False,
            methods=False,
            dunder=False,
            sort=True,
            all=False,
            value=True,
            help=False,
        )
        for device in devices
    ]
    echo._console.print(Columns(panels))


@cli.command(name="directives")
def _directives(
    search: Annotated[Optional[str], typer.Argument(help="Directive ID or Name Search Pattern")] = None,
) -> None:
    """Show all configured devices"""
    # Third Party
    from rich.columns import Columns
    from rich._inspect import Inspect

    # Project
    from hyperglass.state import use_state

    directives = use_state("directives")
    if search is not None:
        pattern = re.compile(search, re.IGNORECASE)
        for directive in directives:
            if pattern.match(directive.id) or pattern.match(directive.name):
                echo._console.print(
                    Inspect(
                        directive,
                        title=directive.name,
                        docs=False,
                        methods=False,
                        dunder=False,
                        sort=True,
                        all=False,
                        value=True,
                        help=False,
                    )
                )
                raise typer.Exit(0)

    panels = [
        Inspect(
            directive,
            title=directive.name,
            docs=False,
            methods=False,
            dunder=False,
            sort=True,
            all=False,
            value=True,
            help=False,
        )
        for directive in directives
    ]
    echo._console.print(Columns(panels))


@cli.command(name="plugins")
def _plugins(
    search: Annotated[Optional[str], typer.Argument(help="Plugin ID or Name Search Pattern")] = None,
    show_input: Annotated[bool, typer.Option("--input", "-i", help="Show Input Plugins only")] = False,
    show_output: Annotated[bool, typer.Option("--output", "-o", help="Show Output Plugins only")] = False,
) -> None:
    """Show all configured plugins"""
    # Third Party
    from rich.columns import Columns

    # Project
    from hyperglass.state import use_state

    to_fetch = ("input", "output")
    if show_input:
        to_fetch = ("input",)
    elif show_output:
        to_fetch = ("output",)

    state = use_state()
    all_plugins = [plugin for _type in to_fetch for plugin in state.plugins(_type)]

    if search is not None:
        pattern = re.compile(search, re.IGNORECASE)
        matching = [plugin for plugin in all_plugins if pattern.match(plugin.name)]
        if len(matching) == 0:
            echo.error(f"No plugins matching {search!r}")
            raise typer.Exit(1)

        echo._console.print(Columns(matching))
        raise typer.Exit(0)

    echo._console.print(Columns(all_plugins))


@cli.command(name="params")
def _params(
    path: Annotated[Optional[str], typer.Argument(help="Parameter Object Path, for example 'messages.no_input'")] = None,
) -> None:
    """Show configuration parameters"""
    # Standard Library
    from operator import attrgetter

    # Third Party
    from rich._inspect import Inspect

    # Project
    from hyperglass.state import use_state

    params = use_state("params")
    if path is not None:
        try:
            value = attrgetter(path)(params)

            echo._console.print(
                Inspect(
                    value,
                    title=f"params.{path}",
                    docs=False,
                    methods=False,
                    dunder=False,
                    sort=True,
                    all=False,
                    value=True,
                    help=False,
                )
            )
            raise typer.Exit(0)
        except AttributeError:
            echo.error(f"{'params.' + path!r} does not exist")
            raise typer.Exit(1)

    panel = Inspect(
        params,
        title="hyperglass Configuration Parameters",
        docs=False,
        methods=False,
        dunder=False,
        sort=True,
        all=False,
        value=True,
        help=False,
    )
    echo._console.print(panel)


@cli.command(name="setup")
def _setup() -> None:
    """Initialize hyperglass setup."""
    # Local
    from .installer import Installer

    with Installer() as start:
        start()


@cli.command(name="settings")
def _settings() -> None:
    """Show hyperglass system settings (environment variables)"""

    # Project
    from hyperglass.settings import Settings

    echo.plain(Settings)


def run() -> None:
    """Run the hyperglass CLI."""
    cli()
