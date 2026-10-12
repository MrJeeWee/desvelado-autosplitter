// Autosplitter Desvelado (Steam v1.1.2)
// Start : Nouvelle partie | Split : nouveau niveau | Fin : seconde porte de la Bonnie room

state("Desvelado_v1_1_2") { }

init
{
    string exe = "Desvelado_v1_1_2.exe";

    // Variables Godot : 0x18 octets chacune, type à +0, valeur à +8
    // StageManager : current_stages_data 0x18, current_stage 0x78, start_zone_time_unix 0x90
    // GameManager  : volumes 0xF0 et 0x108, input_enabled 0x150

    // Tableau des autoloads (enfants de la racine)
    vars.childArrays = new List<DeepPointer>();
    var prefixes = new int[,] {
        { 0x41EC2C8, 0x7F0, 0x20  },
        { 0x429BAC0, 0xE0,  0x1F0 },
        { 0x422AD48, 0x60,  0x1F0 },
        { 0x4255100, 0xA0,  0x1F0 },
        { 0x4255100, 0xA0,  0xB80 },
        { 0x4265CE0, 0xB0,  0x1F0 },
        { 0x428A488, 0x60,  0x1F0 },
        { 0x428A488, 0x60,  0xAF0 },
    };
    foreach (int last in new int[] { 0x178, 0x3C8 })
        for (int i = 0; i < prefixes.GetLength(0); i++)
            vars.childArrays.Add(new DeepPointer(exe, prefixes[i, 0], prefixes[i, 1], prefixes[i, 2], last, 0x0));

    // Chemins directs vers StageManager
    vars.smDirect = new List<DeepPointer> {
        new DeepPointer(exe, 0x41ED2B0, 0x8B8, 0x80, 0x0, 0x240, 0x68, 0x28, 0x0),
        new DeepPointer(exe, 0x4207400, 0x8, 0x2E8, 0x28, 0x0),
    };

    // Nœud -> variables de son script
    vars.Members = (Func<IntPtr, IntPtr>)(node => {
        if (node == IntPtr.Zero) return IntPtr.Zero;
        IntPtr si = game.ReadValue<IntPtr>(node + 0x68);
        if (si == IntPtr.Zero) return IntPtr.Zero;
        return game.ReadValue<IntPtr>(si + 0x28);
    });

    // StageManager : contient une heure Unix plausible
    vars.IsSM = (Func<IntPtr, bool>)(m => {
        if (m == IntPtr.Zero) return false;
        int  t = game.ReadValue<int>(m + 0x90);
        long v = game.ReadValue<long>(m + 0x98);
        return t == 2 && v > 1600000000 && v < 2500000000;
    });

    // GameManager : deux volumes entre 0 et 1, puis un booléen
    vars.IsGM = (Func<IntPtr, bool>)(m => {
        if (m == IntPtr.Zero) return false;
        if (game.ReadValue<int>(m + 0xF0)  != 3) return false;
        if (game.ReadValue<int>(m + 0x108) != 3) return false;
        if (game.ReadValue<int>(m + 0x150) != 1) return false;
        double a = game.ReadValue<double>(m + 0xF8);
        double b = game.ReadValue<double>(m + 0x110);
        return a >= 0 && a <= 1.01 && b >= 0 && b <= 1.01;
    });

    vars.smMembers = IntPtr.Zero;
    vars.gmMembers = IntPtr.Zero;
    vars.searchCooldown = 0;

    vars.stage = -2L;  vars.prevStage = -2L;   // -2 inconnu, -1 null
    vars.data  = -2L;  vars.prevData  = -2L;
    vars.input = -1;
    vars.endNow = false;
    vars.bonnieLocks = 0;
    vars.visited = new HashSet<long>();
}

update
{
    // Adresses mémorisées (fixes pendant la session)
    IntPtr sm = vars.smMembers;
    IntPtr gm = vars.gmMembers;
    if (sm != IntPtr.Zero && !vars.IsSM(sm)) sm = IntPtr.Zero;
    if (gm != IntPtr.Zero && !vars.IsGM(gm)) gm = IntPtr.Zero;

    // Recherche de ce qui manque
    vars.searchCooldown--;
    if (sm == IntPtr.Zero || (gm == IntPtr.Zero && vars.searchCooldown <= 0))
    {
        vars.searchCooldown = 30;

        foreach (DeepPointer p in vars.childArrays)
        {
            if (sm != IntPtr.Zero && gm != IntPtr.Zero) break;
            IntPtr arr;
            try { if (!p.DerefOffsets(game, out arr) || arr == IntPtr.Zero) continue; }
            catch { continue; }

            for (int i = 0; i < 16; i++)
            {
                IntPtr m = vars.Members(game.ReadValue<IntPtr>(arr + i * 8));
                if (m == IntPtr.Zero) continue;
                if (sm == IntPtr.Zero && vars.IsSM(m)) sm = m;
                else if (gm == IntPtr.Zero && vars.IsGM(m)) gm = m;
            }
        }

        if (sm == IntPtr.Zero)
            foreach (DeepPointer p in vars.smDirect)
            {
                IntPtr m;
                try { if (!p.DerefOffsets(game, out m)) continue; } catch { continue; }
                if (vars.IsSM(m)) { sm = m; break; }
            }
    }
    vars.smMembers = sm;
    vars.gmMembers = gm;

    if (sm == IntPtr.Zero)
        return false;

    // Niveau en cours et données de progression
    long stage  = game.ReadValue<long>(sm + 0x80);
    int  stageT = game.ReadValue<int>(sm + 0x78);
    long data   = game.ReadValue<long>(sm + 0x20);
    int  dataT  = game.ReadValue<int>(sm + 0x18);

    vars.prevStage = vars.stage;
    vars.prevData  = vars.data;

    if (dataT == 24) vars.data = data;
    else if (dataT == 0) vars.data = 0L;

    if (stageT == 2 && stage >= 0 && stage <= 11) vars.stage = stage;
    else if (stageT == 0) vars.stage = -1L;

    if (vars.stage == 11 && vars.prevStage != 11)
        vars.bonnieLocks = 0;

    // Bonnie room : 1re perte de contrôle = dialogue, 2e = seconde porte
    if (gm == IntPtr.Zero)
    {
        vars.input = -1;
        return true;
    }

    int ie = game.ReadValue<byte>(gm + 0x158) != 0 ? 1 : 0;
    if (vars.input == 1 && ie == 0 && vars.stage == 11)
    {
        vars.bonnieLocks++;
        if (vars.bonnieLocks >= 2)
            vars.endNow = true;
    }
    vars.input = ie;

    return true;
}

onStart
{
    vars.endNow = false;
    vars.bonnieLocks = 0;
    vars.visited = new HashSet<long>();
    vars.visited.Add(0L);   // Zone 1_1
    vars.visited.Add(11L);  // Bonnie room
}

start
{
    // Nouvelle partie
    return vars.data != vars.prevData && vars.prevData != -2 && vars.data != -2;
}

split
{
    if (vars.endNow)
    {
        vars.endNow = false;
        return true;
    }

    // Nouveau niveau
    if (vars.stage >= 0 && vars.prevStage != -2 && vars.stage != vars.prevStage
        && !vars.visited.Contains((long)vars.stage))
    {
        vars.visited.Add((long)vars.stage);
        return true;
    }

    return false;
}
