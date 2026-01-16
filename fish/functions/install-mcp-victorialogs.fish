function install-mcp-victorialogs --description "Install the latest mcp-victorialogs Darwin ARM64 release"
    set -l install_dir ~/.local/bin
    set -l temp_dir (mktemp -d)
    set -l asset_name "mcp-victorialogs_Darwin_arm64.tar.gz"

    # Get the latest release download URL using GitHub API
    set -l download_url (curl -s https://api.github.com/repos/VictoriaMetrics-Community/mcp-victorialogs/releases/latest \
        | grep -o "https://github.com/VictoriaMetrics-Community/mcp-victorialogs/releases/download/[^\"]*$asset_name")

    if test -z "$download_url"
        echo "Error: Could not find download URL for $asset_name"
        rm -rf $temp_dir
        return 1
    end

    echo "Downloading from: $download_url"

    # Create install directory if it doesn't exist
    mkdir -p $install_dir

    # Download the release
    curl -L -o "$temp_dir/$asset_name" "$download_url"
    if test $status -ne 0
        echo "Error: Download failed"
        rm -rf $temp_dir
        return 1
    end

    # Extract the tarball
    tar -xzf "$temp_dir/$asset_name" -C $temp_dir
    if test $status -ne 0
        echo "Error: Extraction failed"
        rm -rf $temp_dir
        return 1
    end

    # Move the binary to install directory
    mv "$temp_dir/mcp-victorialogs" "$install_dir/"
    if test $status -ne 0
        echo "Error: Failed to move binary to $install_dir"
        rm -rf $temp_dir
        return 1
    end

    # Remove quarantine attribute
    xattr -dr com.apple.quarantine "$install_dir/mcp-victorialogs"

    # Clean up
    rm -rf $temp_dir

    echo "Successfully installed mcp-victorialogs to $install_dir/mcp-victorialogs"
end
