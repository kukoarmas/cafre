docker run --rm -v $(pwd):/documents/ asciidoctor/docker-asciidoctor asciidoctor-pdf -a LA_ORGANIZACION@=CanaryTek -r asciidoctor-diagram --theme /documents/theme/ctk-theme.yml $1
