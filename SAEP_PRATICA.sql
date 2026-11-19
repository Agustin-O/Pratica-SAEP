CREATE TABLE tbl_colaborador (
    id_colaborador SERIAL PRIMARY KEY,
    nome_colaborador VARCHAR(100) NOT NULL,
    cpf VARCHAR(14) UNIQUE NOT NULL CONSTRAINT chk_cpf CHECK (length(cpf) >= 11),
    email_colaborador VARCHAR(100) UNIQUE NOT NULL,
    data_cadastro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    senha_colaborador VARCHAR(100) NOT NULL,
    ativo BOOLEAN DEFAULT TRUE NOT NULL
);

CREATE TABLE tbl_categorias (
    id_categoria SERIAL PRIMARY KEY,
    nome_categoria VARCHAR(50) NOT NULL,
    descricao_ca VARCHAR(150)
);

CREATE TABLE tbl_status (
    id_status SERIAL PRIMARY KEY,
    nome_status VARCHAR(50) NOT NULL,
    descricao_status VARCHAR(150)
);

CREATE TABLE tbl_projetos (
    id_projetos SERIAL PRIMARY KEY,
    titulo VARCHAR(100) NOT NULL,
    descricao TEXT,
    id_colaborador INT NOT NULL REFERENCES tbl_colaborador(id_colaborador),
    id_categoria INT NOT NULL REFERENCES tbl_categorias(id_categoria),
    id_status INT NOT NULL REFERENCES tbl_status(id_status),
    data_criacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_agendamento DATE,
    prazo_entrega DATE NOT NULL CONSTRAINT chk_prazo CHECK (prazo_entrega >= data_agendamento)
);

CREATE TABLE tbl_historico_projetos (
    id_historico SERIAL PRIMARY KEY,
    id_projetos INT NOT NULL REFERENCES tbl_projetos(id_projetos) ON DELETE CASCADE,
    acao VARCHAR(50) NOT NULL,
    descricao TEXT,
    data_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO tbl_colaborador (nome_colaborador, cpf, email_colaborador, senha_colaborador, ativo) VALUES
('Carlos Silva', '12345678901', 'carlos@empresa.com', 'senha123', true),
('Ana Souza', '98765432100', 'ana@empresa.com', 'senha456', true),
('Mariana Lima', '45678912300', 'mariana@empresa.com', 'senha789', false);

INSERT INTO tbl_categorias (nome_categoria, descricao_ca) VALUES
('Desenvolvimento', 'Tarefas ligadas ao desenvolvimento de software'),
('Infraestrutura', 'Manutencao de servidores e redes'),
('Design', 'Criacao de mockups e interfaces');

INSERT INTO tbl_status (nome_status, descricao_status) VALUES
('Pendente', 'Tarefa aguardando inicio'),
('Em Andamento', 'Tarefa sendo executada'),
('Concluido', 'Tarefa finalizada');

CREATE OR REPLACE FUNCTION fn_validar_tarefa()
RETURNS TRIGGER AS $$
DECLARE
    v_ativo BOOLEAN;
BEGIN
    SELECT ativo INTO v_ativo
    FROM tbl_colaborador
    WHERE id_colaborador = NEW.id_colaborador;

    IF v_ativo IS NOT TRUE THEN
        RAISE EXCEPTION 'Não é possível vincular tarefa a um colaborador inativo ou inexistente.';
    END IF;

    IF NEW.data_criacao IS NULL THEN
        NEW.data_criacao := CURRENT_TIMESTAMP;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_tarefa
BEFORE INSERT ON tbl_projetos
FOR EACH ROW
EXECUTE FUNCTION fn_validar_tarefa();

CREATE OR REPLACE FUNCTION fn_log_historico_tarefa()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO tbl_historico_projetos (id_projetos, acao, descricao, data_registro)
    VALUES (NEW.id_projetos, 'INSERÇÃO', 'Tarefa cadastrada e atribuída ao colaborador', CURRENT_TIMESTAMP);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_historico_tarefa
AFTER INSERT ON tbl_projetos
FOR EACH ROW
EXECUTE FUNCTION fn_log_historico_tarefa();

INSERT INTO tbl_projetos (titulo, descricao, id_colaborador, id_categoria, id_status, data_agendamento, prazo_entrega) VALUES
('Migração do Banco', 'Migrar banco para PostgreSQL', 1, 2, 2, '2026-11-20', '2026-11-25'),
('Criação de Landing Page', 'Desenvolver nova página inicial', 2, 3, 1, '2026-11-22', '2026-11-30'),
('Correção de Bugs', 'Ajustar erros no módulo financeiro', 1, 1, 1, '2026-11-21', '2026-11-23');

CREATE VIEW vw_painel_principal AS
SELECT 
    c.nome_colaborador,
    p.titulo,
    cat.nome_categoria,
    p.prazo_entrega,
    s.nome_status
FROM tbl_projetos p
JOIN tbl_colaborador c ON p.id_colaborador = c.id_colaborador
JOIN tbl_categorias cat ON p.id_categoria = cat.id_categoria
JOIN tbl_status s ON p.id_status = s.id_status;

CREATE OR REPLACE FUNCTION fn_buscar_colaboradores(p_termo VARCHAR)
RETURNS TABLE (
    id_colaborador INT,
    nome_colaborador VARCHAR,
    cpf VARCHAR,
    email_colaborador VARCHAR,
    ativo BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id_colaborador,
        c.nome_colaborador,
        c.cpf,
        c.email_colaborador,
        c.ativo
    FROM tbl_colaborador c
    WHERE c.nome_colaborador ILIKE '%' || p_termo || '%'
       OR c.email_colaborador ILIKE '%' || p_termo || '%';
END;
$$ LANGUAGE plpgsql;

CREATE VIEW vw_cronograma_prazos AS
SELECT 
    s.nome_status,
    (p.prazo_entrega - CURRENT_DATE) AS dias_restantes,
    c.nome_colaborador,
    p.prazo_entrega
FROM tbl_projetos p
JOIN tbl_colaborador c ON p.id_colaborador = c.id_colaborador
JOIN tbl_status s ON p.id_status = s.id_status
ORDER BY p.prazo_entrega ASC;
