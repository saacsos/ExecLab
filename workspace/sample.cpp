#include <bits/stdc++.h>

using namespace std;

int main() {
    ios_base::sync_with_stdio(0);
    cin.tie(0);
    int t, n, total, x;
    cin >> t >> n;
    for (int i = 0; i < t; ++i) {
        total = 0;
        for (int j = 0; j < n; ++j) {
            cin >> x;
            total += x;
        }
        cout << total << endl;
    }
    return 0;
}