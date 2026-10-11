#include <iostream>
#include <fstream>
#include <string>
#include <algorithm>

// Meaningful check: strips whitespace, http(s)://, www., and trailing slashes
std::string normalizeUrl(std::string url) {
    // Trim whitespace
    url.erase(0, url.find_first_not_of(" \n\r\t"));
    url.erase(url.find_last_not_of(" \n\r\t") + 1);

    if (url.find("http://") == 0) url.erase(0, 7);
    else if (url.find("https://") == 0) url.erase(0, 8);
    
    if (url.find("www.") == 0) url.erase(0, 4);
    
    if (!url.empty() && url.back() == '/') url.pop_back();
    
    return url;
}

int main(int argc, char* argv[]) {
    if (argc != 3) {
        std::cerr << "Usage: " << argv[0] << " <file> <url>\n";
        return 1;
    }
    
    std::string filePath = argv[1];
    std::string newUrl = argv[2];
    std::string normalizedNew = normalizeUrl(newUrl);

    // Read existing file to check for duplicates
    std::ifstream fin(filePath);
    if (fin.is_open()) {
        std::string line;
        while (std::getline(fin, line)) {
            if (line.empty()) continue;
            if (normalizeUrl(line) == normalizedNew) {
                // Duplicate found in a meaningful way, do nothing and exit successfully
                return 0; 
            }
        }
        fin.close();
    }

    // Append the new link
    std::ofstream fout(filePath, std::ios::app);
    if (!fout.is_open()) {
        return 1; // Return error code to trigger notification
    }
    fout << newUrl << "\n";
    fout.close();

    return 0;
}